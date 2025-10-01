import XCTest
import Mechanosynthesis
import Numerics

// Test the steepest descent algorithm from INQ.
//
// Eventually, we want to test out the multigrid acceleration algorithm from:
// https://aaltodoc.aalto.fi/server/api/core/bitstreams/dce1a73a-c087-4f38-815b-61bdb458610f/content
// This is simpler than other multigrid eigensolvers and a good first step.
// After that, implement the rather complex multigrid solver that "converges in
// a single SCF cycle".
final class EigensolverTests: XCTestCase {
  static let console: Bool = false
  
  // Reproduce the test from the shorter file:
  // https://gitlab.com/npneq/inq/-/blob/master/src/solvers/steepest_descent.hpp
  //
  // Compute everything in FP64.
  func testDiagonalMatrixDouble() throws {
    // Create row-major hamiltonian matrices.
    let numPoints = 100
    let numVectors = 12
    var identityMatrix: [[Complex<Double>]] = []
    var diagonalMatrix: [[Complex<Double>]] = []
    
    for i in 0..<numPoints {
      var identityRow: [Complex<Double>] = []
      var diagonalRow: [Complex<Double>] = []
      for j in 0..<numPoints {
        if i == j {
          identityRow.append(Complex(1))
          diagonalRow.append(Complex(Double(i) + 1))
        } else {
          identityRow.append(.zero)
          diagonalRow.append(.zero)
        }
      }
      identityMatrix.append(identityRow)
      diagonalMatrix.append(diagonalRow)
    }
    
    // Create column-major matrices of eigenvectors.
    let volumeElement = 1 / Double(numPoints)
    let diagonalOp = diagonalMatrix
    var phi: [[Complex<Double>]] = []
    var rhs: [[Complex<Double>]] = []
    
    for electronID in 0..<numVectors {
      var phiVector: [Complex<Double>] = []
      var rhsVector: [Complex<Double>] = []
      for cellID in 0..<numPoints {
        let expr1 = Double(electronID * cellID) * 0.1
        let expr2 = Double(cellID * (electronID + 1)) / 2
        phiVector.append(Complex.exp(Complex(0, expr1)))
        rhsVector.append(Complex(Double.cos(expr2)))
      }
      phi.append(phiVector)
      rhs.append(rhsVector)
    }
    
    func overlapDiagonal(
      _ lhs: [[Complex<Double>]],
      _ rhs: [[Complex<Double>]]
    ) -> [Complex<Double>] {
      var output: [Complex<Double>] = []
      precondition(lhs.count == 12)
      for electronID in 0..<lhs.count {
        let lhsElectron = lhs[electronID]
        let rhsElectron = rhs[electronID]
        precondition(lhsElectron.count == 100)
        var sum: Complex<Double> = .zero
        for cellID in 0..<lhsElectron.count {
          let lhsValue = lhsElectron[cellID]
          let rhsValue = rhsElectron[cellID]
          sum += lhsValue.conjugate * rhsValue * Complex(volumeElement)
        }
        output.append(sum)
      }
      return output
    }
    
    // Perform an NT matrix multiplication. Assume the left-hand side is
    // diagonal to reduce execution time in debug mode.
    func gemmDiagonal(
      _ lhs: [[Complex<Double>]],
      _ rhs: [[Complex<Double>]]
    ) -> [[Complex<Double>]] {
      var output: [[Complex<Double>]] = []
      precondition(lhs.count == 100)
      precondition(rhs.count == 12)
      for electronID in 0..<rhs.count {
        let electron = rhs[electronID]
        precondition(electron.count == 100)
        var outputVector: [Complex<Double>] = []
        for cellID in 0..<electron.count {
          let lhsElement = lhs[cellID][cellID]
          let rhsElement = electron[cellID]
          outputVector.append(lhsElement * rhsElement)
        }
        output.append(outputVector)
      }
      return output
    }
    
    func steepestDescent(
      hamiltonian: [[Complex<Double>]],
      preconditioner: [[Complex<Double>]],
      rhs: [[Complex<Double>]],
      phi: inout [[Complex<Double>]]
    ) {
      for stepID in 0..<5 {
        let HΨ = gemmDiagonal(hamiltonian, phi)
        let EΨ = rhs
        var residual = HΨ
        for electronID in 0..<12 {
          for cellID in 0..<100 {
            let lhs = HΨ[electronID][cellID]
            let rhs = EΨ[electronID][cellID]
            residual[electronID][cellID] = lhs - rhs
          }
        }
        
        let r = gemmDiagonal(preconditioner, residual)
        let Hr = gemmDiagonal(hamiltonian, r)
        let HrHr = overlapDiagonal(Hr, Hr)
        let rHr = overlapDiagonal(r, Hr)
        let rr = overlapDiagonal(r, r)
        
        // Display the norm residual.
        var output: String = ""
        output += "\(stepID)"
        precondition(phi.count == 12)
        for electronID in 0..<phi.count {
          output += "\t"
          let value = rr[electronID].real
          output += String(format: "%.3f", value)
        }
        if EigensolverTests.console {
          print(output)
        }
        
        var lambda: [Complex<Double>] = []
        for electronID in 0..<phi.count {
          let ca = HrHr[electronID]
          let cb  = 4 * rHr[electronID].real
          let cc = rr[electronID]
          
          let sqarg = Complex(cb * cb) - 4 * ca * cc
          let signB = (Complex(cb) * sqarg).real >= 0 ? Double(1) : -1
          var qq = Complex(signB) * Complex.sqrt(sqarg)
          qq = Complex(cb) + qq
          qq *= Complex(-0.5)
          lambda.append(cc / qq)
        }
        
        for electronID in 0..<12 {
          for cellID in 0..<100 {
            let lhs = phi[electronID][cellID]
            let rhs = residual[electronID][cellID]
            phi[electronID][cellID] = lhs + lambda[electronID] * rhs
          }
        }
      }
    }
    
    let numIterations = 50
    for iterationID in 0...numIterations {
      if iterationID > 0 {
        steepestDescent(
          hamiltonian: diagonalOp, preconditioner: identityMatrix,
          rhs: rhs, phi: &phi)
      }
      
      let HΨ = gemmDiagonal(diagonalOp, phi)
      let EΨ = rhs
      var residual = HΨ
      for electronID in 0..<12 {
        for cellID in 0..<100 {
          let lhs = HΨ[electronID][cellID]
          let rhs = EΨ[electronID][cellID]
          residual[electronID][cellID] = lhs - rhs
        }
      }
      let normResidual = overlapDiagonal(residual, residual)
      
      if EigensolverTests.console {
        print("  Iteration \(iterationID):")
      }
      for electronID in 0..<numVectors {
        var output = "    state \(electronID)"
        output += "  res = \(normResidual[electronID])"
        if EigensolverTests.console {
          print(output)
        }
        
        if iterationID == numIterations {
          let normres = normResidual[electronID].real
          XCTAssertLessThan(normres.magnitude, 1e-8)
        }
      }
    }
  }
  
  // Reproduce the test from the longer file:
  // https://gitlab.com/npneq/inq/-/blob/master/src/eigensolvers/steepest_descent.hpp
  //
  // Compute everything in FP32. For this test case, there is no benefit to
  // accumulating sums in FP64.
  func testDiagonalMatrixFloat() throws {
    typealias Real = Float
    
    // Create row-major hamiltonian matrices.
    let numPoints = 100
    let numVectors = 12
    var identityMatrix: [[Complex<Real>]] = []
    var diagonalMatrix: [[Complex<Real>]] = []
    
    for i in 0..<numPoints {
      var identityRow: [Complex<Real>] = []
      var diagonalRow: [Complex<Real>] = []
      for j in 0..<numPoints {
        if i == j {
          identityRow.append(Complex(1))
          diagonalRow.append(Complex(Real(i) + 1))
        } else {
          identityRow.append(.zero)
          diagonalRow.append(.zero)
        }
      }
      identityMatrix.append(identityRow)
      diagonalMatrix.append(diagonalRow)
    }
    
    // Create column-major matrices of eigenvectors.
    let volumeElement = 1 / Real(numPoints)
    let diagonalOp = diagonalMatrix
    var phi: [[Complex<Real>]] = []
    
    for electronID in 0..<numVectors {
      var phiVector: [Complex<Real>] = []
      for cellID in 0..<numPoints {
        let expr1 = Real(electronID * cellID) * 0.1
        phiVector.append(Complex.exp(Complex(0, expr1)))
      }
      phi.append(phiVector)
    }
    
    func overlapDiagonal(
      _ lhs: [[Complex<Real>]],
      _ rhs: [[Complex<Real>]]
    ) -> [Complex<Real>] {
      var output: [Complex<Real>] = []
      precondition(lhs.count == 12)
      for electronID in 0..<lhs.count {
        let lhsElectron = lhs[electronID]
        let rhsElectron = rhs[electronID]
        precondition(lhsElectron.count == 100)
        var sum: Complex<Real> = .zero
        for cellID in 0..<lhsElectron.count {
          let lhsValue = lhsElectron[cellID]
          let rhsValue = rhsElectron[cellID]
          let outValue = lhsValue.conjugate * rhsValue * Complex(volumeElement)
          sum += Complex<Real>(outValue)
        }
        output.append(Complex<Real>(sum))
      }
      return output
    }
    
    // Perform an NT matrix multiplication. Assume the left-hand side is
    // diagonal to reduce execution time in debug mode.
    func gemmDiagonal(
      _ lhs: [[Complex<Real>]],
      _ rhs: [[Complex<Real>]]
    ) -> [[Complex<Real>]] {
      var output: [[Complex<Real>]] = []
      precondition(lhs.count == 100)
      precondition(rhs.count == 12)
      for electronID in 0..<rhs.count {
        let electron = rhs[electronID]
        precondition(electron.count == 100)
        var outputVector: [Complex<Real>] = []
        for cellID in 0..<electron.count {
          let lhsElement = lhs[cellID][cellID]
          let rhsElement = electron[cellID]
          outputVector.append(lhsElement * rhsElement)
        }
        output.append(outputVector)
      }
      return output
    }
    
    func steepestDescent(
      hamiltonian: [[Complex<Real>]],
      preconditioner: [[Complex<Real>]],
      phi: inout [[Complex<Real>]]
    ) {
      var HΨ = gemmDiagonal(hamiltonian, phi)
      
      for _ in 0..<5 {
        let E = overlapDiagonal(phi, HΨ)
        let norm = overlapDiagonal(phi, phi)
        var eigenvalueNorm = E
        
        var r = HΨ
        for electronID in 0..<12 {
          eigenvalueNorm[electronID] /= norm[electronID]
          for cellID in 0..<100 {
            let E = eigenvalueNorm[electronID]
            let Ψ = phi[electronID][cellID]
            r[electronID][cellID] -= E * Ψ
          }
        }
        r = gemmDiagonal(preconditioner, r)
        
        let Hr = gemmDiagonal(hamiltonian, r)
        let rr = overlapDiagonal(r, r)
        let Ψr = overlapDiagonal(phi, r)
        let rHr = overlapDiagonal(r, Hr)
        let ΨHr = overlapDiagonal(phi, Hr)
        
        var λ: [Real] = []
        for electronID in 0..<phi.count {
          let m0 = rr[electronID]
          let m1 = Ψr[electronID]
          let m2 = rHr[electronID]
          let m3 = ΨHr[electronID]
          let m4 = E[electronID]
          let m5 = norm[electronID]
          
          let ca = (m0 * m3 - m2 * m1).real
          let cb = (m5 * m2 - m4 * m0).real
          let cc = (m4 * m1 - m3 * m5).real
          let determinant = cb + (cb * cb - 4 * ca * cc).squareRoot()
          λ.append(2 * cc / determinant)
        }
        
        for electronID in 0..<12 {
          for cellID in 0..<100 {
            let lambda = Complex(λ[electronID])
            phi[electronID][cellID] += lambda * r[electronID][cellID]
            HΨ[electronID][cellID] += lambda * Hr[electronID][cellID]
          }
        }
      }
      
      let norm = overlapDiagonal(phi, phi)
      for electronID in 0..<12 {
        func normalize(norm: Complex<Real>) {
          let normalizationFactor = 1 / norm.real.squareRoot()
          for cellID in 0..<100 {
            phi[electronID][cellID] *= Complex(normalizationFactor)
          }
        }
        normalize(norm: norm[electronID])
        
        var dotProducts: [Complex<Real>] = []
        for predecessorID in 0..<electronID {
          let predecessor = phi[predecessorID]
          let current = phi[electronID]
          let dotProduct = overlapDiagonal([predecessor], [current])
          dotProducts.append(dotProduct[0])
        }
        for predecessorID in 0..<electronID {
          let Ψ = phi[predecessorID]
          for cellID in 0..<100 {
            phi[electronID][cellID] -= dotProducts[predecessorID] * Ψ[cellID]
          }
        }
        
        let norm = overlapDiagonal([phi[electronID]], [phi[electronID]])
        normalize(norm: norm[0])
      }
    }
    
    let numIterations = 70
    for iterationID in 0...numIterations {
      if iterationID > 0 {
        steepestDescent(
          hamiltonian: diagonalOp, preconditioner: identityMatrix, phi: &phi)
      }
      
      let HΨ = gemmDiagonal(diagonalOp, phi)
      let E = overlapDiagonal(phi, HΨ)
      var residual = HΨ
      for electronID in 0..<12 {
        for cellID in 0..<100 {
          let Ψ = phi[electronID][cellID]
          residual[electronID][cellID] -= E[electronID] * Ψ
        }
      }
      let normResidual = overlapDiagonal(residual, residual)
      
      if EigensolverTests.console {
        print("  Iteration \(iterationID):")
      }
      for electronID in 0..<numVectors {
        var output = "    state \(electronID)"
        output += "  evalue = \(E[electronID])"
        output += "  res = \(normResidual[electronID])"
        if EigensolverTests.console {
          print(output)
        }
        
        if iterationID == numIterations {
          let eigenvalue = E[electronID].real
          let expected = Real(electronID + 1)
          XCTAssertEqual(eigenvalue, expected, accuracy: 1e-3)
          
          let normres = normResidual[electronID].real
          XCTAssertLessThan(normres.magnitude, 1e-3)
        }
      }
    }
  }
  
  // Modify the test for the Laplacian operator, to become a test for a particle
  // in a finite potential well.
  //
  // Instead of complex FP64, use real FP32. In addition, test what happens when
  // Gram-Schmidt orthogonalization is replaced with "fast orthogonalization".
  func testFinitePotentialWell() throws {
    typealias Real = Float
    
    let numCells = 50
    let numWellCells = 20
    let numElectrons = 5
    
    let L: Real = 10
    let V0: Real = 1
    var boundStates: [(v: Real, u: Real)]
    
    if L == 10 && V0 == 1 {
      boundStates = [
        (1.375, 6.396),
        (2.743, 6.517),
        (4.095, 5.765),
        (5.412, 4.551),
        (6.636, 2.442),
      ]
    } else if L == 10 && V0 == 10 {
      boundStates = [
        (1.504, 22.310),
        (3.007, 22.158),
        (4.509, 21.901),
        (6.011, 21.901),
        (7.511, 21.061),
        (9.010, 20.465),
      ]
    } else {
      fatalError("Unrecognized set of conditions.")
    }
    
    // INQ has [2, -1, 2], but the actual Laplacian operator is [1, -2, 1].
    // The properties of both operators have been examined; they produce very
    // similar behavior for unbound periodic particles.
    let filter: [Real] = [1, -2, 1]
    
    func hamiltonian(_ Ψ: [[Real]]) -> [[Real]] {
      var output: [[Real]] = []
      for electronID in Ψ.indices {
        var outputVector: [Real] = []
        let currentΨ = Ψ[electronID]
        
        for cellID in currentΨ.indices {
          var value = filter[1] * currentΨ[cellID]
          if cellID < numCells - 1 {
            value += filter[2] * currentΨ[cellID + 1]
          }
          if cellID > 0 {
            value += filter[0] * currentΨ[cellID - 1]
          }
          value *= -0.5
          var x = Real(cellID) + 0.5 - Real(numCells) / 2
          
          let h = L / Real(numWellCells)
          value /= (h * h)
          x *= h
          
          // Examine what happens if the potential energy is shifted, so
          // bound states have negative potential energy and unbound states have
          // zero potential energy.
          if x.magnitude <= L / 2 {
            value -= V0 * currentΨ[cellID]
          }
          outputVector.append(value)
        }
        output.append(outputVector)
      }
      return output
    }
    
    func dot(_ lhs: [Real], _ rhs: [Real]) -> Real {
      guard lhs.count == rhs.count else {
        fatalError("Unequal counts.")
      }
      var sum: Double = .zero
      let h = L / Real(numWellCells)
      for cellID in lhs.indices {
        sum += Double(lhs[cellID] * rhs[cellID] * h)
      }
      
      return Real(sum)
    }
    
    func normalize(_ x: [Real]) -> [Real] {
      let norm = dot(x, x)
      return x.map {
        $0 / norm.squareRoot()
      }
    }
    
    var Ψ: [[Real]] = []
    for electronID in 0..<numElectrons {
      let (v, u) = boundStates[numElectrons - 1 - electronID]
      let a = u / (L / 2)
      let k = v / (L / 2)
      
      // Un-normalized versions of A, B, and H.
      var A: Real = 0
      var B: Real = 0
      var H: Real = 0
      if electronID % 2 == 0 {
        // Symmetric case.
        A = .nan
        B = 1
        H = Real.cos(k * L / 2) / Real.exp(-a * L / 2)
      } else {
        // Asymmmetric case.
        A = 1
        B = .nan
        H = Real.sin(k * L / 2) / Real.exp(-a * L / 2)
      }
      
      var outputVector: [Real] = []
      for cellID in 0..<numCells {
        var x = Real(cellID) + 0.5 - Real(numCells) / 2
        var value: Real
        
        let h = L / Real(numWellCells)
        x *= h
        
        if electronID % 2 == 0 {
          // Symmetric case.
          if x < -L / 2 {
            value = H * Real.exp(a * x)
          } else if x <= L / 2 {
            value = B * Real.cos(k * x)
          } else {
            value = H * Real.exp(-a * x)
          }
        } else {
          // Asymmetric case.
          if x < -L / 2 {
            value = -H * Real.exp(a * x)
          } else if x <= L / 2 {
            value = A * Real.sin(k * x)
          } else {
            value = H * Real.exp(-a * x)
          }
        }
        
        // This converges even if we use the original setup procedure from INQ.
//        if electronID == cellID {
//          value = 1
//        } else {
//          value = 0
//        }
        
        outputVector.append(value)
      }
      
      outputVector = normalize(outputVector)
      Ψ.append(outputVector)
    }
    
    func eigensolver(
      hamiltonian: ([[Real]]) -> [[Real]],
      phi originalΨ: [[Real]]
    ) -> [[Real]] {
      var Ψ = originalΨ
      var HΨ = hamiltonian(originalΨ)
      
      // Try just 1 eigensolver step to demonstrate a non-negligible
      // improvement to stability.
      for _ in 0..<5 {
        let E = zip(Ψ, HΨ).map(dot(_:_:))
        let norm = zip(Ψ, Ψ).map(dot(_:_:))
        
        var r: [[Real]] = []
        for electronID in Ψ.indices {
          let currentΨ = Ψ[electronID]
          let currentHΨ = HΨ[electronID]
          var outputVector: [Real] = []
          let evnorm = E[electronID] / norm[electronID]
          
          for cellID in currentΨ.indices {
            let value = currentHΨ[cellID] - evnorm * currentΨ[cellID]
            outputVector.append(value)
          }
          r.append(outputVector)
        }
        
        let Hr = hamiltonian(r)
        let rr = zip(r, r).map(dot(_:_:))
        let Ψr = zip(Ψ, r).map(dot(_:_:))
        let rHr = zip(r, Hr).map(dot(_:_:))
        let ΨHr = zip(Ψ, Hr).map(dot(_:_:))
        
        var λ: [Real] = []
        for electronID in 0..<Ψ.count {
          let m0 = rr[electronID]
          let m1 = Ψr[electronID]
          let m2 = rHr[electronID]
          let m3 = ΨHr[electronID]
          let m4 = E[electronID]
          let m5 = norm[electronID]
          
          let ca = (m0 * m3 - m2 * m1)
          let cb = (m5 * m2 - m4 * m0)
          let cc = (m4 * m1 - m3 * m5)
          let determinant = cb + (cb * cb - 4 * ca * cc).squareRoot()
          if determinant.magnitude < 1e-15 {
            // This happens if we are perfectly converged.
            λ.append(0)
          } else {
            λ.append(2 * cc / determinant)
          }
        }
        
        for electronID in Ψ.indices {
          for cellID in Ψ[electronID].indices {
            let lambda = λ[electronID]
            Ψ[electronID][cellID] += lambda * r[electronID][cellID]
            HΨ[electronID][cellID] += lambda * Hr[electronID][cellID]
          }
        }
      }
      
      for electronID in Ψ.indices {
        Ψ[electronID] = normalize(Ψ[electronID])
      }
      let h = L / Real(numWellCells)
      let priorities = (0..<numElectrons).map { Real(-$0) }
      Ψ = OrthogonalizeTests.fastOrthogonalize(
        Ψ, priorities: priorities, d3r: h)
      return Ψ
    }
    
    let numIterations = 50
    for iterationID in 0...numIterations {
      /*
       solvers::steepest_descent(laplacian, identity, phi);
       
       auto residual = laplacian(phi);
       auto eigenvalues = operations::overlap_diagonal(phi, residual);
       operations::shift(eigenvalues, phi, residual, -1.0);
       auto normres = operations::overlap_diagonal(residual);
       
       for(int ivec = 0; ivec < phi.set_size(); ivec++){
         tfm::format(std::cout, " state %4d  evalue = %18.12f  res = %5.0e\n", ivec + 1, real(eigenvalues[ivec]), real(normres[ivec]));
       }
       */
      
      if EigensolverTests.console {
        print("Iteration \(iterationID)")
      }
      
      if iterationID > 0 {
        Ψ = eigensolver(hamiltonian: hamiltonian(_:), phi: Ψ)
      }
      
      let HΨ = hamiltonian(Ψ)
      var E: [Real] = []
      var r: [[Real]] = []
      for electronID in 0..<numElectrons {
        let currentΨ = Ψ[electronID]
        let currentHΨ = HΨ[electronID]
        let currentE = dot(currentΨ, currentHΨ)
        E.append(currentE)
        
        var rVector: [Real] = []
        for cellID in 0..<numCells {
          let value = currentHΨ[cellID] - currentE * currentΨ[cellID]
          rVector.append(value)
        }
        r.append(rVector)
      }
      
        for electronID in 0..<numElectrons {
          let v = boundStates[electronID].v
          let eigenvalue = E[electronID]
          let expectedE = 2 * v * v / (L * L) - V0
          let normres = dot(r[electronID], r[electronID])
          
          if iterationID == numIterations {
            XCTAssertLessThan(
              normres.magnitude, 1e-10,
              "Electron \(electronID) failed to converge.")
            
            if electronID == 4 {
              XCTAssertEqual(
                eigenvalue, expectedE, accuracy: 0.1,
                "Electron \(electronID) had the wrong eigenvalue.")
            } else {
              XCTAssertEqual(
                eigenvalue, expectedE, accuracy: 0.04,
                "Electron \(electronID) had the wrong eigenvalue.")
            }
          }
          
          if EigensolverTests.console {
            var output = ""
            output += "  state \(electronID)"
            output += "  evalue = \(eigenvalue)"
            output += "  (expected \(expectedE))"
            output += "  res = \(normres)"
            print(output)
          }
        }
      
//      for cellID in 0..<numCells {
//        for electronID in 0..<numElectrons {
//          let value = HΨ[electronID][cellID]
//          var repr = String(format: "%.4f", value)
//          if !repr.starts(with: "-") {
//            repr = " " + repr
//          }
//          print("  \(repr),", separator: "", terminator: "")
//        }
//        print()
//      }
    }
  }
}
