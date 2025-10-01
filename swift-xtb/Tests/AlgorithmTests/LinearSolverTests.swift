import XCTest
import Numerics

// Performance of different algorithms
//
// ========================================================================== //
// Methods
// ========================================================================== //
//
// Specification of multigrid V-cycle
//   A-B-C-D-E
//
//   A GSRB (1x)
//   -> B GSRB (2x)
//   ---> C GSRB (4x)
//   -> D GSRB (2x)
//   E GSRB (1x)
//   update solution
//
//   One V-cycle counts as one iteration. It is effectively the compute cost
//   of two Gauss-Seidel iterations.
//
// ========================================================================== //
// Results (Raw Data)
// ========================================================================== //
//
// h = 0.25, gridSize = 8, cellCount = 512
//                       0 iters  ||r|| = 394.27557
// Gauss-Seidel         30 iters  ||r|| = 6.5650797      0.002 seconds
// Conjugate Gradient   30 iters  ||r|| = 0.00030688613  0.003 seconds
// Preconditioned CG    15 iters  ||r|| = 0.00023875975  0.003 seconds
// Multigrid 1-1-1-1-1  15 iters  ||r|| = 0.017259505    0.004 seconds
// Multigrid 1-2-1-2-2  10 iters  ||r|| = 0.00020144212  0.003 seconds
// Multigrid 1-4-2       7 iters  ||r|| = 0.00019803157  0.003 seconds
// FAS 2-2-4-2-2        13 iters  ||r|| = 0.00018249848  0.004 seconds
// FAS 3-3-6-3-3        10 iters  ||r|| = 0.00013220003  0.004 seconds
// FAS 4-4-8-4-4         8 iters  ||r|| = 0.00016010087  0.004 seconds
//
// h = 0.125, gridSize = 16, cellCount = 4096
//                       0 iters  ||r|| = 3091.9424
// Gauss-Seidel         30 iters  ||r|| = 277.43747     0.016 seconds
// Conjugate Gradient   30 iters  ||r|| = 0.09551496    0.017 seconds
// Preconditioned CG    15 iters  ||r|| = 0.0032440922  0.024 seconds
// Multigrid 1-1-1-1-1  15 iters  ||r|| = 0.0023769636  0.025 seconds
// Multigrid 1-2-1-2-2  12 iters  ||r|| = 0.0025058207  0.024 seconds
// Multigrid 1-2-2-2-2  10 iters  ||r|| = 0.0023211893  0.021 seconds
// Multigrid 1-2-4-2-2  12 iters  ||r|| = 0.0025251452  0.025 seconds
// FAS 2-2-2-4-2-2-2    21 iters  ||r|| = 0.0019460453  0.031 seconds
// FAS 3-3-3-6-3-3-3    13 iters  ||r|| = 0.0019811026  0.026 seconds
// FAS 4-4-4-8-4-4-4    10 iters  ||r|| = 0.001796775   0.025 seconds
//
// h = 0.0625, gridSize = 32, cellCount = 32,768
//                           0 iters  ||r|| = 24494.229
// Gauss-Seidel             60 iters  ||r|| = 1308.8044    0.250 seconds
// Conjugate Gradient       60 iters  ||r|| = 0.49065304   0.258 seconds
// Preconditioned CG        30 iters  ||r|| = 0.048568394  0.364 seconds
// Multigrid 1-1-1-1-1-1-1  30 iters  ||r|| = 0.029823668  0.408 seconds
// Multigrid 1-2-2-1-2-2-2  15 iters  ||r|| = 0.02897086   0.242 seconds
// Multigrid 1-2-4-2-2      15 iters  ||r|| = 0.028649306  0.251 seconds
// FAS 2-2-2-2-4-2-2-2-2    55 iters  ||r|| = 0.022709914  0.640 seconds
// FAS 3-3-3-3-6-3-3-3-3    20 iters  ||r|| = 0.02041208   0.300 seconds
// FAS 4-4-4-4-8-4-4-4-4    15 iters  ||r|| = 0.01959731   0.283 seconds
//
// h = 0.0313, gridSize = 64, cellCount = 262,144
//                             0 iters  ||r|| = 195015.61
// Gauss-Seidel               99 iters  ||r|| = 5887.104    3.311 seconds
// Conjugate Gradient         99 iters  ||r|| = 53.441914   3.375 seconds
// Preconditioned CG          50 iters  ||r|| = 0.72252524  4.823 seconds
// Multigrid 1-1-1-1-1-1-1    35 iters  ||r|| = 0.45097157  3.831 seconds
// Multigrid 1-2-2-1-2-2-2    30 iters  ||r|| = 0.3642269   3.951 seconds
// Multigrid 1-2-2-2-2-2-2    20 iters  ||r|| = 0.36008823  2.601 seconds
// Multigrid 1-2-2-4-2-2-2    20 iters  ||r|| = 0.30006418  2.613 seconds
// FAS 3-3-3-3-3-6-3-3-3-3-3  35 iters  ||r|| = 0.23221506  4.315 seconds
// FAS 4-4-4-4-4-8-4-4-4-4-4  20 iters  ||r|| = 0.22813758  3.047 seconds
//
// h = 0.0156, gridSize = 128, cellCount = 2,097,152
//                                 0 iters  ||r|| = 1556438.4
// Preconditioned CG              60 iters  ||r|| = 1209.9086  46.300 seconds
// Preconditioned CG              99 iters  ||r|| = 11.659912  75.554 seconds
// Multigrid 1-1-1-1-1-1-1        60 iters  ||r|| = 225.7327   52.499 seconds
// Multigrid 1-1-1-2-1-1-1        60 iters  ||r|| = 25.65553   52.680 seconds
// Multigrid 1-2-2-2-2-2-2        60 iters  ||r|| = 6.335201   62.544 seconds
// Multigrid 1-2-2-4-2-2-2        40 iters  ||r|| = 3.906945   42.194 seconds
// Multigrid 1-2-2-2-1-2-2-2-2    28 iters  ||r|| = 3.576714   29.415 seconds
// FAS 4-4-4-4-4-4-8-4-4-4-4-4-4  30 iters  ||r|| = 2.6634037  35.504 seconds
//
// ========================================================================== //
// Results (Summary)
// ========================================================================== //
//
// Pattern for reliable convergence (original multigrid):
// Multigrid 1-4-2                 7 V-cycles  ||r|| = 0.000198   0.003 seconds
// Multigrid 1-2-4-2-2            12 V-cycles  ||r|| = 0.002525   0.025 seconds
// Multigrid 1-2-4-2-2            15 V-cycles  ||r|| = 0.028649   0.251 seconds
// Multigrid 1-2-2-4-2-2-2        20 V-cycles  ||r|| = 0.300064   2.613 seconds
// Multigrid 1-2-2-4-2-2-2        40 V-cycles  ||r|| = 3.906945  42.194 seconds
//
// Pattern for reliable convergence (after rewrite, which added FAS):
// FAS 4-4-8-4-4                   8 V-cycles  ||r|| = 0.000160   0.004 seconds
// FAS 4-4-4-8-4-4-4              10 V-cycles  ||r|| = 0.001796   0.025 seconds
// FAS 4-4-4-4-8-4-4-4-4          15 V-cycles  ||r|| = 0.019597   0.283 seconds
// FAS 4-4-4-4-4-8-4-4-4-4-4      20 V-cycles  ||r|| = 0.228137   3.047 seconds
// FAS 4-4-4-4-4-4-8-4-4-4-4-4-4  30 V-cycles  ||r|| = 2.663403  35.504 seconds
//
// The pattern is much simpler with FAS. The solver converges consistently and
// requires no fine-tuning.
//
// ========================================================================== //
// Discussion
// ========================================================================== //
//
// NOTE: These notes were made when there was a major bug in the multigrid
// implementation. Now, multigrid performs much better. It is consistently
// faster than conjugate gradient.
//
// Ranked by ease of implementation:
// 1) Jacobi
// 2) Gauss-Seidel
// 3) Conjugate gradient
// 4) Preconditioned conjugate gradient
// 5) Multigrid
//
// Preconditioned CG seems like the best tradeoff between complexity and speed.
// It converges consistently in every situation. Multigrid requires careful
// tuning of the tree depth and often fails to converge with the wrong V-cycle
// scheme. However, it has the potential to be more efficient, especially with
// BMR FAS-FMG.
//
// I'm also unsure how adaptive mesh refinement will affect the performance of
// these algorithms. The path length to jump between levels would increase
// significantly. Multigrid would coalesce the overhead of interpolation
// and coarsening operations. However, the CG preconditioner could be modified
// with higher / anisotropic sample count at the nuclear singularity.
//
// ========================================================================== //
// Conclusion
// ========================================================================== //
//
// Final conclusion: support both the 33-point PCG and multigrid solvers in
// this library. PCG is definitely more robust and requires less fine tuning.
// However, multigrid outperforms it for large systems. There might be an API
// for the user to fine-tune the multigrid scheme.
//
// This is similar to MM4, which supports two integrators:
// - .verlet (more efficient for small systems; default)
// - .multipleTimeStep (more efficient for large systems)
//
// Mechanosynthesis would have two solvers:
// - .conjugateGradient (more robust; default)
// - .multigrid (more efficient)
//
// ========================================================================== //
// Results (Raw Data)
// ========================================================================== //
//
// 7-point Laplacian
//
// Spacing  | Cells | RMS Average   | MAD Average   | Maximum Cell  | Order
// -------- | ----- | ------------- | ------------- | ------------- | -----
// h = 1/4  |   8^3 | RMS: 0.044557 | MAD: 0.068089 | MAX: 0.096520 | n/a
// h = 1/8  |  16^3 | RMS: 0.032344 | MAD: 0.028211 | MAX: 0.189478 | 1.27
// h = 1/16 |  32^3 | RMS: 0.022969 | MAD: 0.010023 | MAX: 0.377876 | 1.49
// h = 1/32 |  64^3 | RMS: 0.016251 | MAD: 0.003268 | MAX: 0.755470 | 1.62
// h = 1/64 | 128^3 | RMS: 0.011492 | MAD: 0.001010 | MAX: 1.510849 | 1.69
//
// 19-point Laplacian on lowest level, no Mehrstellen correction
//
// TODO
final class LinearSolverTests: XCTestCase {
  static let gridSize: Int = 8
  static let h: Float = 2 / Float(gridSize)
  static var cellCount: Int { gridSize * gridSize * gridSize }
  
  // MARK: - Utilities
  
  // Create the 'b' vector, which equals -4πρ.
  static func createScaledChargeDensity() -> [Float] {
    var output = [Float](repeating: .zero, count: cellCount)
    for permutationZ in -1...0 {
      for permutationY in -1...0 {
        for permutationX in -1...0 {
          var indices = SIMD3(repeating: gridSize / 2)
          indices[0] += permutationX
          indices[1] += permutationY
          indices[2] += permutationZ
          
          // Place 1/8 of the charge density in each of the 8 cells.
          let chargeEnclosed: Float = 1.0 / 8
          let chargeDensity = chargeEnclosed / (h * h * h)
          
          // Multiply -4π with ρ, resulting in -4πρ.
          let rhsValue = (-4 * Float.pi) * chargeDensity
          
          // Write the right-hand side to memory.
          var cellID = indices.z * (gridSize * gridSize)
          cellID += indices.y * gridSize + indices.x
          output[cellID] = rhsValue
        }
      }
    }
    return output
  }
  
  static func createAddress(indices: SIMD3<Int>) -> Int {
    indices.z * (gridSize * gridSize) + indices.y * gridSize + indices.x
  }
  
  // Apply the 'A' matrix (∇^2), while omitting ghost cells.
  //
  // The Laplacian has second-order accuracy.
  static func applyLaplacianLinearPart(_ x: [Float]) -> [Float] {
    guard x.count == cellCount else {
      fatalError("Dimensions of 'x' did not match problem size.")
    }
    
    // Iterate over the cells.
    var output = [Float](repeating: 0, count: cellCount)
    for indexZ in 0..<gridSize {
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          var dotProduct: Float = .zero
          
          // Apply the FMA on the diagonal.
          let cellIndices = SIMD3(indexX, indexY, indexZ)
          let cellAddress = createAddress(indices: cellIndices)
          let cellValue = x[cellAddress]
          dotProduct += -6 / (h * h) * cellValue
          
          // Iterate over the faces.
          for faceID in 0..<6 {
            let coordinateID = faceID / 2
            let coordinateShift = (faceID % 2 == 0) ? -1 : 1
            
            // Locate the neighboring cell.
            var neighborIndices = SIMD3(indexX, indexY, indexZ)
            neighborIndices[coordinateID] += coordinateShift
            
            if all(neighborIndices .>= 0) && all(neighborIndices .< gridSize) {
              let neighborAddress = createAddress(indices: neighborIndices)
              let neighborValue = x[neighborAddress]
              dotProduct += 1 / (h * h) * neighborValue
            }
          }
          
          // Store the dot product.
          output[cellAddress] = dotProduct
        }
      }
    }
    
    return output
  }
  
  // The Laplacian, omitting contributions from the input 'x'.
  //
  // Fills ghost cells with the multipole expansion of the charge enclosed.
  static func applyLaplacianBoundary() -> [Float] {
    // Iterate over the cells.
    var output = [Float](repeating: 0, count: cellCount)
    for indexZ in 0..<gridSize {
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          var dotProduct: Float = .zero
          
          let cellIndices = SIMD3(indexX, indexY, indexZ)
          let cellAddress = createAddress(indices: cellIndices)
          
          // Iterate over the faces.
          for faceID in 0..<6 {
            let coordinateID = faceID / 2
            let coordinateShift = (faceID % 2 == 0) ? -1 : 1
            
            // Locate the neighboring cell.
            var neighborIndices = SIMD3(indexX, indexY, indexZ)
            neighborIndices[coordinateID] += coordinateShift
            
            if all(neighborIndices .>= 0) && all(neighborIndices .< gridSize) {
              
            } else {
              var neighborPosition = SIMD3<Float>(neighborIndices)
              neighborPosition = h * (neighborPosition + 0.5)
              var nucleusPosition = SIMD3(repeating: Float(gridSize))
              nucleusPosition = h * (nucleusPosition * 0.5)
              
              // Generate a ghost value from the point charge approximation.
              let r = neighborPosition - nucleusPosition
              let distance = (r * r).sum().squareRoot()
              let neighborValue = 1 / distance
              dotProduct += 1 / (h * h) * neighborValue
            }
          }
          
          // Store the dot product.
          output[cellAddress] = dotProduct
        }
      }
    }
    
    return output
  }
  
  // Create the analytical value for the solution.
  static func createReferenceSolution() -> [Float] {
    var output = [Float](repeating: .zero, count: Self.cellCount)
    for indexZ in 0..<Self.gridSize {
      for indexY in 0..<Self.gridSize {
        for indexX in 0..<Self.gridSize {
          let cellIndices = SIMD3(indexX, indexY, indexZ)
          let cellAddress = Self.createAddress(indices: cellIndices)
          
          var cellPosition = SIMD3<Float>(cellIndices)
          cellPosition = Self.h * (cellPosition + 0.5)
          var nucleusPosition = SIMD3(repeating: Float(Self.gridSize))
          nucleusPosition = Self.h * (nucleusPosition * 0.5)
          
          // Generate a ghost value from the point charge approximation.
          let r = cellPosition - nucleusPosition
          let distance = (r * r).sum().squareRoot()
          let cellValue = 1 / distance
          
          // Store the dot product.
          output[cellAddress] = cellValue
        }
      }
    }
    return output
  }
  
  // Returns the 2-norm of the residual vector.
  static func createResidualNorm(solution: [Float]) -> Float {
    guard solution.count == Self.cellCount else {
      fatalError("Solution had incorrect size.")
    }
    
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    
    let L1x = Self.applyLaplacianLinearPart(solution)
    let r = Self.shift(b, scale: -1, correction: L1x)
    let r2 = Self.dot(r, r)
    
    return r2.squareRoot()
  }
  
  // Shift a vector by a constant times another vector.
  //
  // Returns: original + scale * correction
  static func shift(
    _ original: [Float],
    scale: Float,
    correction: [Float]
  ) -> [Float] {
    var output = [Float](repeating: .zero, count: Self.cellCount)
    for cellID in 0..<Self.cellCount {
      var cellValue = original[cellID]
      cellValue += scale * correction[cellID]
      output[cellID] = cellValue
    }
    return output
  }
  
  // Take the dot product of two vectors.
  static func dot(
    _ lhs: [Float],
    _ rhs: [Float]
  ) -> Float {
    var accumulator: Double = .zero
    for cellID in 0..<Self.cellCount {
      let lhsValue = lhs[cellID]
      let rhsValue = rhs[cellID]
      accumulator += Double(lhsValue * rhsValue)
    }
    return Float(accumulator)
  }
  
  // MARK: - Tests
  
  // Jacobi method:
  //
  // Ax = b
  // (D + L + U)x = b
  // Dx = b - (L + U)x
  // Dx = b - (A - D)x
  // Dx = b - Ax + Dx
  // x = x + D^{-1} (b - Ax)
  func testJacobiMethod() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Check the residual norm at the start of iterations.
    do {
      let residualNorm = Self.createResidualNorm(solution: x)
      XCTAssertEqual(residualNorm, 394, accuracy: 1)
    }
    
    // Execute the iterations.
    for _ in 0..<20 {
      let L1x = Self.applyLaplacianLinearPart(x)
      let r = Self.shift(b, scale: -1, correction: L1x)
      
      let D = -6 / (Self.h * Self.h)
      x = Self.shift(x, scale: 1 / D, correction: r)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 50)
  }
  
  // Gauss-Seidel method:
  //
  // x_i = (1 / a_ii) (b_i - Σ_(j ≠ i) a_ij x_j)
  //
  // Red-black scheme:
  //
  // iterate over all the red cells in parallel
  // iterate over all the black cells in parallel
  // only works with 2nd order FD
  //
  // a four-color scheme would work with Mehrstellen, provided we process the
  // multigrid one level at a time
  func testGaussSeidelMethod() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Execute the iterations.
    for _ in 0..<20 {
      executeSweep(red: true, black: false)
      executeSweep(red: false, black: true)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 25)
    
    // Updates all of the selected cells in-place.
    //
    // NOTE: This function references the variables 'x' and 'b', declared in
    // the outer scope.
    func executeSweep(red: Bool, black: Bool) {
      for indexZ in 0..<Self.gridSize {
        for indexY in 0..<Self.gridSize {
          for indexX in 0..<Self.gridSize {
            var dotProduct: Float = .zero
            
            // Mask out either the red or black cells.
            let parity = indexX ^ indexY ^ indexZ
            switch parity & 1 {
            case 0:
              guard red else {
                continue
              }
            case 1:
              guard black else {
                continue
              }
            default:
              fatalError("This should never happen.")
            }
            
            // Iterate over the faces.
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              
              if all(neighborIndices .>= 0),
                 all(neighborIndices .< Self.gridSize) {
                let neighborAddress = Self
                  .createAddress(indices: neighborIndices)
                let neighborValue = x[neighborAddress]
                dotProduct += 1 / (Self.h * Self.h) * neighborValue
              }
            }
            
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = Self.createAddress(indices: cellIndices)
            
            // Overwrite the current value.
            let rhsValue = b[cellAddress]
            let diagonalValue: Float = -6 / (Self.h * Self.h)
            let newValue = (rhsValue - dotProduct) / diagonalValue
            x[cellAddress] = newValue
          }
        }
      }
    }
  }
  
  // Conjugate gradient method:
  //
  // r = b - Ax
  // p = r - Σ_i < p_i | A | r > / < p_i | A | p_i >
  // a = < p | r > / < p | A | p >
  // x = x + a p
  //
  // Efficient version:
  //
  // r = b - Ax
  // p = r
  // repeat
  //   a = < r | r > / < p | A | p >
  //   x_new = x + a p
  //   r_new = r - a A p
  //
  //   b = < r_new | r_new > / < r | r >
  //   p_new = r_new + b p
  func testConjugateGradientMethod() throws {
    // Prepare the right-hand side.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    
    // Prepare the solution vector.
    var x = [Float](repeating: .zero, count: Self.cellCount)
    let L1x = Self.applyLaplacianLinearPart(x)
    var r = Self.shift(b, scale: -1, correction: L1x)
    var p = r
    var rr = Self.dot(r, r)
    
    // Execute the iterations.
    for _ in 0..<20 {
      let Ap = Self.applyLaplacianLinearPart(p)
      
      let a = rr / Self.dot(p, Ap)
      let xNew = Self.shift(x, scale: a, correction: p)
      let rNew = Self.shift(r, scale: -a, correction: Ap)
      let rrNew = Self.dot(rNew, rNew)
      
      let b = rrNew / rr
      let pNew = Self.shift(rNew, scale: b, correction: p)
      
      x = xNew
      r = rNew
      p = pNew
      rr = rrNew
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
  }
  
  // Preconditioned conjugate gradient method:
  //
  // r = b - Ax
  // p = K r
  // repeat
  //   a = < r | K | r > / < p | A | p >
  //   x_new = x + a p
  //   r_new = r - a A p
  //
  //   b = < r_new | K | r_new > / < r | K | r >
  //   p_new = K r_new + b p
  func testPreconditionedConjugateGradient() throws {
    // Prepare the right-hand side.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    
    // Prepare the solution vector.
    var x = [Float](repeating: .zero, count: Self.cellCount)
    let L1x = Self.applyLaplacianLinearPart(x)
    var r = Self.shift(b, scale: -1, correction: L1x)
    var Kr = applyLaplacianPreconditioner(r)
    var rKr = Self.dot(r, Kr)
    var p = Kr
    
    // Execute the iterations.
    for _ in 0..<10 {
      let Ap = Self.applyLaplacianLinearPart(p)
      
      let a = rKr / Self.dot(p, Ap)
      let xNew = Self.shift(x, scale: a, correction: p)
      let rNew = Self.shift(r, scale: -a, correction: Ap)
      let KrNew = applyLaplacianPreconditioner(rNew)
      let rKrNew = Self.dot(rNew, KrNew)
      
      let b = rKrNew / rKr
      let pNew = Self.shift(KrNew, scale: b, correction: p)
      
      x = xNew
      r = rNew
      Kr = KrNew
      rKr = rKrNew
      p = pNew
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
    
    // Applies the 33-point convolution preconditioner.
    func applyLaplacianPreconditioner(_ x: [Float]) -> [Float] {
      let gridSize = Self.gridSize
      let cellCount = Self.cellCount
      
      @_transparent
      func createAddress(indices: SIMD3<Int16>) -> Int {
        Int(indices.z) * (gridSize * gridSize) +
        Int(indices.y) * gridSize +
        Int(indices.x)
      }
      
      // Pre-compile a list of neighbor offsets.
      var neighborData: [SIMD4<Int16>] = []
      for offsetZ in -2...2 {
        for offsetY in -2...2 {
          for offsetX in -2...2 {
            let indices = SIMD3(Int16(offsetX), Int16(offsetY), Int16(offsetZ))
            let integerDistanceSquared = (indices &* indices).wrappedSum()
            
            // This tolerance creates a 33-point convolution kernel.
            guard integerDistanceSquared <= 4 else {
              continue
            }
            
            // Execute the formula for matrix elements.
            var K: Float = .zero
            K += 0.6 * Float.exp(-2.25 * Float(integerDistanceSquared))
            K += 0.4 * Float.exp(-0.72 * Float(integerDistanceSquared))
            let quantized = Int16(K * 32767)
            
            // Pack the data into a compact 64-bit word.
            let vector = SIMD4(indices, quantized)
            neighborData.append(vector)
          }
        }
      }
      
      // Iterate over the cells.
      var output = [Float](repeating: 0, count: cellCount)
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Iterate over the convolution points.
            var accumulator: Float = .zero
            
            // The test took 0.015 seconds before.
            // 0.013 seconds
            let cellIndices64 = SIMD3(indexX, indexY, indexZ)
            let cellIndices = SIMD3<Int16>(truncatingIfNeeded: cellIndices64)
            for vector in neighborData {
              let offset = unsafeBitCast(vector, to: SIMD3<Int16>.self)
              let neighborIndices = cellIndices &+ offset
              guard all(neighborIndices .>= 0),
                    all(neighborIndices .< Int16(gridSize)) else {
                continue
              }
              
              // Read the neighbor data point from memory.
              let neighborAddress = createAddress(indices: neighborIndices)
              let neighborValue = x[neighborAddress]
              let K = Float(vector[3]) / 32767
              accumulator += neighborValue * K
            }
            
            // Write the convolution result to memory.
            let cellAddress = createAddress(indices: cellIndices)
            output[cellAddress] = accumulator
          }
        }
      }
      
      return output
    }
  }
  
  func testMultigridMethod() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Execute the iterations.
    for _ in 0..<15 {
      // Initialize the residual.
      let L1x = Self.applyLaplacianLinearPart(x)
      let rFine = Self.shift(b, scale: -1, correction: L1x)
      
      // Smoothing iterations on the first level.
      var eFine = gaussSeidelSolve(
        r: rFine,
        coarseness: 1)
      eFine = multigridCoarseLevel(
        e: eFine, 
        r: rFine,
        fineLevelCoarseness: 1,
        fineLevelIterations: 1)
      
      // Update the solution.
      x = Self.shift(x, scale: 1, correction: eFine)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
    
    // A recursive function call within the multigrid V-cycle.
    func multigridCoarseLevel(
      e: [Float], r: [Float], fineLevelCoarseness: Int, fineLevelIterations: Int
    ) -> [Float] {
      var eFine = e
      var rFine = r
      
      // Restrict from fine to coarse.
      let rFineCorrected = correctResidual(
        e: eFine,
        r: rFine,
        coarseness: fineLevelCoarseness)
      let rCoarse = shiftResolution(
        fineGrid: rFineCorrected,
        coarseGrid: [],
        fineLevelCoarseness: fineLevelCoarseness,
        shiftingUp: true)
      
      // Smoothing iterations on the coarse level.
      let coarseLevelCoarseness = 2 * fineLevelCoarseness
      var coarseLevelIterations: Int
      if coarseLevelCoarseness == 1 {
        fatalError("This should never happen.")
      } else if coarseLevelCoarseness == 2 {
        coarseLevelIterations = 4
      } else {
        coarseLevelIterations = 1
      }
      var eCoarse = gaussSeidelSolve(
        r: rCoarse, 
        coarseness: coarseLevelCoarseness,
        iterations: coarseLevelCoarseness)
      
      // Shift to a higher level.
      if coarseLevelCoarseness < 2 {
        eCoarse = multigridCoarseLevel(
          e: eCoarse,
          r: rCoarse,
          fineLevelCoarseness: coarseLevelCoarseness,
          fineLevelIterations: coarseLevelIterations)
      }
      
      // Prolong from coarse to fine.
      eFine = shiftResolution(
        fineGrid: eFine,
        coarseGrid: eCoarse,
        fineLevelCoarseness: fineLevelCoarseness, 
        shiftingUp: false)
      rFine = correctResidual(
        e: eFine,
        r: rFine,
        coarseness: fineLevelCoarseness)
      
      // Smoothing iterations on the fine level.
      let δeFine = gaussSeidelSolve(
        r: rFine,
        coarseness: fineLevelCoarseness,
        iterations: fineLevelIterations)
      for cellID in eFine.indices {
        eFine[cellID] += δeFine[cellID]
      }
      return eFine
    }
    
    // Solves the equation ∇^2 e = r, then returns e.
    func gaussSeidelSolve(
      r: [Float], coarseness: Int, iterations: Int = 1
    ) -> [Float] {
      // Allocate an array for the solution vector.
      let arrayLength = Self.cellCount / (coarseness * coarseness * coarseness)
      var e = [Float](repeating: .zero, count: arrayLength)
      gaussSeidelIteration(e: &e, r: r, coarseness: coarseness, iteration: 0)
      gaussSeidelIteration(e: &e, r: r, coarseness: coarseness, iteration: 1)
      for iterationID in 1..<iterations {
        gaussSeidelIteration(
          e: &e, r: r, coarseness: coarseness, iteration: 2 * iterationID + 0)
        gaussSeidelIteration(
          e: &e, r: r, coarseness: coarseness, iteration: 2 * iterationID + 1)
      }
      return e
    }
    
    // Gauss-Seidel with red-black ordering.
    func gaussSeidelIteration(
      e: inout [Float], r: [Float], coarseness: Int, iteration: Int
    ) {
      let h = Self.h * Float(coarseness)
      let gridSize = Self.gridSize / coarseness
      func createAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (gridSize * gridSize) + indices.y * gridSize + indices.x
      }
      
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Mask out either the red or black cells.
            let parity = indexX ^ indexY ^ indexZ
            guard (iteration & 1) == (parity & 1) else {
              continue
            }
            
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(indices: cellIndices)
            
            // Iterate over the faces.
            var faceAccumulator: Float = .zero
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              guard all(neighborIndices .>= 0),
                    all(neighborIndices .< gridSize) else {
                // Add 'zero' to the accumulator.
                continue
              }
              
              // Add the neighbor's value to the accumulator.
              let neighborAddress = createAddress(indices: neighborIndices)
              if iteration == 0 {
                let neighborValue = r[neighborAddress]
                let λ = h * h / 6
                faceAccumulator += 1 / (h * h) * (-λ * neighborValue)
              } else {
                let neighborValue = e[neighborAddress]
                faceAccumulator += 1 / (h * h) * neighborValue
              }
            }
            
            // Fetch the values to evaluate GSRB_LEVEL(e, R, h).
            let rValue = r[cellAddress]
            
            // Update the error in-place.
            let λ = h * h / 6
            e[cellAddress] = λ * (faceAccumulator - rValue)
          }
        }
      }
    }
    
    // Merges the error vector with the residual.
    func correctResidual(
      e: [Float], r: [Float], coarseness: Int
    ) -> [Float] {
      let h = Self.h * Float(coarseness)
      let gridSize = Self.gridSize / coarseness
      func createAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (gridSize * gridSize) + indices.y * gridSize + indices.x
      }
      
      // Allocate an array for the output.
      let cellCount = gridSize * gridSize * gridSize
      var output = [Float](repeating: .zero, count: cellCount)
      
      // Iterate over the cells.
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            var dotProduct: Float = .zero
            
            // Apply the FMA on the diagonal.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(indices: cellIndices)
            let cellValue = e[cellAddress]
            dotProduct += -6 / (h * h) * cellValue
            
            // Iterate over the faces.
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              guard all(neighborIndices .>= 0),
                    all(neighborIndices .< gridSize) else {
                // Add 'zero' to the dot product.
                continue
              }
              
              let neighborAddress = createAddress(indices: neighborIndices)
              let neighborValue = e[neighborAddress]
              dotProduct += 1 / (h * h) * neighborValue
            }
            
            // Update the residual.
            let L2e = dotProduct
            output[cellAddress] = r[cellAddress] - L2e
          }
        }
      }
      return output
    }
    
    // Performs a power-2 shift to a coarser level.
    func shiftResolution(
      fineGrid: [Float], coarseGrid: [Float],
      fineLevelCoarseness: Int, shiftingUp: Bool
    ) -> [Float] {
      let fineGridSize = Self.gridSize / fineLevelCoarseness
      let coarseGridSize = fineGridSize / 2
      func createFineAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (fineGridSize * fineGridSize) +
        indices.y * fineGridSize + indices.x
      }
      func createCoarseAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (coarseGridSize * coarseGridSize) +
        indices.y * coarseGridSize + indices.x
      }
      
      // Create the output grid.
      var output: [Float]
      if shiftingUp {
        let coarseCellCount = coarseGridSize * coarseGridSize * coarseGridSize
        output = [Float](repeating: .zero, count: coarseCellCount)
      } else {
        output = fineGrid
      }
      
      // Iterate over the coarse grid.
      for indexZ in 0..<coarseGridSize {
        for indexY in 0..<coarseGridSize {
          for indexX in 0..<coarseGridSize {
            // Read from the coarse grid.
            let coarseIndices = SIMD3<Int>(indexX, indexY, indexZ)
            let coarseAddress = createCoarseAddress(indices: coarseIndices)
            let coarseValue = coarseGrid[coarseAddress]
            
            // Iterate over the footprint on the finer grid.
            var accumulator: Float = .zero
            for permutationZ in 0..<2 {
              for permutationY in 0..<2 {
                for permutationX in 0..<2 {
                  var fineIndices = 2 &* coarseIndices
                  fineIndices[0] += permutationX
                  fineIndices[1] += permutationY
                  fineIndices[2] += permutationZ
                  let fineAddress = createFineAddress(indices: fineIndices)
                  
                  if shiftingUp {
                    // Read from the fine grid.
                    let fineValue = fineGrid[fineAddress]
                    accumulator += (1.0 / 8) * fineValue
                  } else {
                    // Update the fine grid.
                    output[fineAddress] += coarseValue
                  }
                }
              }
            }
            
            // Update the coarse grid.
            if shiftingUp {
              output[coarseAddress] = accumulator
            }
          }
        }
      }
      return output
    }
  }
  
  // Refactor the multigrid code, fix the bug with iteration count, and
  // convert the solver into the FAS scheme.
  // - Modify the storage of the e-vector, permitting RB ordering with Mehr. ✅
  // - Does it achieve the same convergence rates as the original multigrid? ✅
  // - Does it perform better for the 128x128x128 grid attempting to peak the
  //   V-cycle at 64x64x64? ✅
  //
  // Exact equations for the Mehrstellen correction:
  //
  // B4^{-1} A4 u4 = f4
  // t3 = B3^{-1} A3 avg u4 - avg B4^{-1} A4 u4
  // f3 = avg f4
  // -> B3^{-1} A3 u3 = f3 + t3
  // -> t2 = B2^{-1} A2 avg u3 - avg B3^{-1} A3 u3 + avg t3
  // -> f2 = avg f3
  // ---> B2^{-1} A2 u2 = f2 + t2
  // ---> t1 = B1^{-1} A1 avg u2 - avg B2^{-1} A2 u2 + avg t2
  // ---> f1 = avg f2
  // -----> B1^{-1} A1 u1 = f1 + t1
  // ---> u2 += interp (u1 - avg u2)
  // ---> B2^{-1} A2 u2 = f2 + t2
  // -> u3 += interp (u2 - avg u3)
  // -> B3^{-1} A3 u3 = f3 + t3
  // u4 += interp (u3 - avg u4)
  // B4^{-1} A4 u4 = f4
  //
  // Rearranging the equations to avoid the matrix inversion:
  //
  // solved by u4 = U4
  // A4 u4 = B4 f4
  // t3 = L3 avg u4 + avg (B4 f4 - A4 u4)
  //
  // -> solved by u3 = avg u4
  // -> L3 u3 = t3
  // -> t2 = L2 avg u3 + avg (t3 - L3 u3)
  //
  // ---> solved by u2 = avg u3
  // ---> L2 u2 = t2
  // ---> t1 = L1 avg u2 + avg (t2 - L2 u2)
  //
  // -----> solved by u1 = avg u2
  // -----> L1 u1 = t1
  //
  // ---> solved by u1 = avg u2
  // ---> u2 += interp (u1 - avg u2)
  // ---> L2 u2 = t2
  //
  // -> solved by u2 = avg u3
  // -> u3 += interp (u2 - avg u3)
  // -> L3 u3 = t3
  //
  // solved by u3 = avg u4
  // u4 += interp (u3 - avg u4)
  // A4 u4 = B4 f4
  //
  // Mehrstellen should only be applied at the level where it's the source of
  // truth. This explains why Mehrstellen is "numerically unstable" on coarse
  // grids.
  func testFullApproximationScheme() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Heuristic for number of iterations:
    // - Optimal iteration count: (2/3) * stageCount^2
    // - Conservative iteration count: stageCount^2
    //
    // Data used for parametrization:
    // 8x8x8         9 iterations > 8 iterations
    // 16x16x16     16 iterations > 10 iterations
    // 32x32x32     25 iterations > 15 iterations
    // 64x64x64     36 iterations > 20 iterations
    // 128x128x128  49 iterations > 30 iterations
    let stageCount = Self.gridSize.trailingZeroBitCount
    let iterationCount = stageCount * stageCount
    for _ in 0..<iterationCount {
      // Execute eight smoothing iterations on each level (4 up, 4 down).
      cycle(solution: &x, rightHandSide: b, stages: stageCount)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
    
    // Check the accuracy of the solution.
    do {
      // Create variables to accumulate the population statistics.
      var rmsAccumulator: Double = .zero
      var madAccumulator: Double = .zero
      var maxAccumulator: Float = .zero
      
      // Iterate over the grid.
      for indexZ in 0..<Self.gridSize {
        for indexY in 0..<Self.gridSize {
          for indexX in 0..<Self.gridSize {
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = Self.createAddress(indices: cellIndices)
            let cellValue = x[cellAddress]
            
            let position = (SIMD3<Float>(cellIndices) + 0.5) * Self.h
            let rDelta = position - SIMD3<Float>(1, 1, 1)
            let r = (rDelta * rDelta).sum().squareRoot()
            let expected = 1 / r
            
            let error = (cellValue - expected).magnitude
            let drTerm = Self.h * Self.h * Self.h
            rmsAccumulator += Double(error * error * drTerm)
            madAccumulator += Double(error * drTerm)
            maxAccumulator = max(maxAccumulator, error)
          }
        }
      }
      
      // Check the population statistics.
      let rms = Float(rmsAccumulator).squareRoot()
      let mad = Float(madAccumulator)
      let max = maxAccumulator
      XCTAssertLessThan(rms, 0.10)
      XCTAssertLessThan(mad, 0.14)
      XCTAssertLessThan(max, 0.19)
    }
    
    // Perform a V-cycle.
    // - solution: The solution, which will be updated in-place.
    // - rightHandSide: 'b' in the linear equation.
    // - stages: The number of V-cycle stages left, including the current one.
    //           For example, 3 stages would indicate:
    //             4x4x4 granularity
    //             2x2x2 granularity
    //             1x1x1 granularity (current level)
    //           Note that 2^3 = 8, and the highest multigrid level is not
    //           8x8x8. Rather, the highest level should be:
    //             2^{stages-1} x 2^{stages-1} x 2^{stages-1}
    func cycle(
      solution: inout [Float],
      rightHandSide: [Float],
      stages: Int
    ) {
      guard stages >= 1 else {
        fatalError("There must be enough stages to include the current one.")
      }
      
      // Perform two iterations of Gauss-Seidel smoothing.
      smooth(solution: &solution, rightHandSide: rightHandSide)
      
      let coarseStages = stages - 1
      if coarseStages > 0 {
        // Restrict the solution to a coarser level.
        var coarseSolution = restrict(solution)
        
        // Use a double negative to compute the defect correction, without
        // creating a dedicated Swift function.
        //
        // L3 avg u4 + avg (B4 f4 - A4 u4)
        // L3 avg u4 - avg (A4 u4 - B4 f4)
        let residual = negativeResidual(
          solution: solution,
          rightHandSide: rightHandSide)
        let τ = negativeResidual(
          solution: coarseSolution,
          rightHandSide: restrict(residual))
        
        // Call this function, but one level higher.
        cycle(
          solution: &coarseSolution,
          rightHandSide: τ,
          stages: coarseStages)
        
        // Add the correction to the current solution.
        let correction = prolong(subtract(coarseSolution, restrict(solution)))
        solution = add(solution, correction)
      }
      
      // Perform two iterations of Gauss-Seidel smoothing.
      smooth(solution: &solution, rightHandSide: rightHandSide)
    }
    
    // Whether Mehrstellen discretization should be used.
    func shouldUseMehrstellen(gridSize: Int16) -> Bool {
      // The current implementation of Mehrstellen has a bug.
      false
    }
    
    func createGridSize(cellCount: Int) -> Int16 {
      // Estimate the cube root.
      let cubeRoot = Float.root(Float(cellCount), 3)
      let cubeRootRounded = Int16(cubeRoot.rounded(.toNearestOrEven))
      
      // Check the correctness of the estimate.
      let cube =
      Int(cubeRootRounded) *
      Int(cubeRootRounded) *
      Int(cubeRootRounded)
      guard cube == cellCount else {
        fatalError("Cube root was incorrect: \(cube) != \(cellCount).")
      }
      
      // Return the cube root.
      return cubeRootRounded
    }
    
    func createSpacing(gridSize: Int16) -> Float {
      Self.h * Float(Self.gridSize / Int(gridSize))
    }
    
    @_transparent
    func createAddress(_ indices: SIMD3<Int16>, gridSize: Int16) -> Int {
      Int(indices.z) * Int(gridSize) * Int(gridSize) +
      Int(indices.y) * Int(gridSize) +
      Int(indices.x)
    }
    
    // Split the solution into red and black halves.
    func split(solution: [Float]) -> (
      red: [Float], black: [Float]
    ) {
      let gridSize = createGridSize(cellCount: solution.count)
      var red = [Float](repeating: .zero, count: solution.count / 2)
      var black = [Float](repeating: .zero, count: solution.count / 2)
      
      // Iterate over the cells.
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Read the solution value from memory.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(cellIndices, gridSize: gridSize)
            let cellValue = solution[cellAddress]
            
            // Write the solution value to memory.
            let parity = indexX ^ indexY ^ indexZ
            let isRed = (parity & 1) == 0
            if isRed {
              red[cellAddress / 2] = cellValue
            } else {
              black[cellAddress / 2] = cellValue
            }
          }
        }
      }
      return (red, black)
    }
    
    // Merge the two halves of the solution.
    func merge(red: [Float], black: [Float]) -> [Float] {
      var solution = [Float](repeating: .zero, count: red.count + black.count)
      let gridSize = createGridSize(cellCount: solution.count)
      
      // Iterate over the cells.
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Locate the current cell.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(cellIndices, gridSize: gridSize)
            var cellValue: Float
            
            // Read the solution value from memory.
            let parity = indexX ^ indexY ^ indexZ
            let isRed = (parity & 1) == 0
            if isRed {
              cellValue = red[cellAddress / 2]
            } else {
              cellValue = black[cellAddress / 2]
            }
            
            // Write the solution to memory.
            solution[cellAddress] = cellValue
          }
        }
      }
      return solution
    }
    
    func add(_ lhs: [Float], _ rhs: [Float]) -> [Float] {
      var output = [Float](repeating: .zero, count: lhs.count)
      for cellID in lhs.indices {
        let lhsValue = lhs[cellID]
        let rhsValue = rhs[cellID]
        let sumValue = lhsValue + rhsValue
        output[cellID] = sumValue
      }
      return output
    }
    
    func subtract(_ lhs: [Float], _ rhs: [Float]) -> [Float] {
      var output = [Float](repeating: .zero, count: lhs.count)
      for cellID in lhs.indices {
        let lhsValue = lhs[cellID]
        let rhsValue = rhs[cellID]
        let sumValue = lhsValue - rhsValue
        output[cellID] = sumValue
      }
      return output
    }
    
    func createLevelTransferPermutations() -> [SIMD3<Int16>] {
      var permutations: [SIMD3<Int16>] = []
      for permutationZ in 0..<2 {
        for permutationY in 0..<2 {
          for permutationX in 0..<2 {
            let permutationSet = SIMD3(
              Int16(permutationX),
              Int16(permutationY),
              Int16(permutationZ))
            permutations.append(permutationSet)
          }
        }
      }
      return permutations
    }
    
    func restrict(_ fineGrid: [Float]) -> [Float] {
      var coarseGrid = [Float](repeating: .zero, count: fineGrid.count / 8)
      let fineGridSize = createGridSize(cellCount: fineGrid.count)
      let coarseGridSize = fineGridSize / 2
      
      // Create a list of index permutations.
      let permutations = createLevelTransferPermutations()
      
      // Iterate over the coarse grid.
      for indexZ in 0..<coarseGridSize {
        for indexY in 0..<coarseGridSize {
          for indexX in 0..<coarseGridSize {
            // Iterate over the footprint on the finer grid.
            var accumulator: Float = .zero
            for permutation in permutations {
              var fineIndices = 2 &* SIMD3(indexX, indexY, indexZ)
              fineIndices &+= permutation
              let fineAddress = createAddress(
                fineIndices, gridSize: fineGridSize)
              
              // Read from the fine grid.
              let fineValue = fineGrid[fineAddress]
              accumulator += (1.0 / 8) * fineValue
            }
            
            // Write to the coarse grid.
            let coarseIndices = SIMD3(indexX, indexY, indexZ)
            let coarseAddress = createAddress(
              coarseIndices, gridSize: coarseGridSize)
            coarseGrid[coarseAddress] = accumulator
          }
        }
      }
      return coarseGrid
    }
    
    func prolong(_ coarseGrid: [Float]) -> [Float] {
      var fineGrid = [Float](repeating: .zero, count: coarseGrid.count * 8)
      let coarseGridSize = createGridSize(cellCount: coarseGrid.count)
      let fineGridSize = coarseGridSize * 2
      
      // Create a list of index permutations.
      let permutations = createLevelTransferPermutations()
      
      // Iterate over the coarse grid.
      for indexZ in 0..<coarseGridSize {
        for indexY in 0..<coarseGridSize {
          for indexX in 0..<coarseGridSize {
            // Read from the coarse grid.
            let coarseIndices = SIMD3(indexX, indexY, indexZ)
            let coarseAddress = createAddress(
              coarseIndices, gridSize: coarseGridSize)
            let coarseValue = coarseGrid[coarseAddress]
            
            // Iterate over the footprint on the finer grid.
            for permutation in permutations {
              var fineIndices = 2 &* SIMD3(indexX, indexY, indexZ)
              fineIndices &+= permutation
              let fineAddress = createAddress(
                fineIndices, gridSize: fineGridSize)
              
              // Write to the fine grid.
              fineGrid[fineAddress] = coarseValue
            }
          }
        }
      }
      return fineGrid
    }
    
    func createEdgePermutations() -> [SIMD3<Int16>] {
      var permutations: [SIMD3<Int16>] = []
      permutations.append(SIMD3(1, 1, 0))
      permutations.append(SIMD3(1, 0, 1))
      permutations.append(SIMD3(0, 1, 1))
      permutations.append(SIMD3(1, -1, 0))
      permutations.append(SIMD3(1, 0, -1))
      permutations.append(SIMD3(0, 1, -1))
      permutations += permutations.map { 0 &- $0 }
      return permutations
    }
    
    // The two types of cells that are updated in alternation.
    enum Sweep {
      case red
      case black
    }
    
    // A descriptor for a relaxation.
    struct RelaxationDescriptor {
      var sweep: Sweep?
      var red: [Float]?
      var black: [Float]?
      var rightHandSide: [Float]?
    }
    
    func smooth(
      solution: inout [Float],
      rightHandSide: [Float],
      iterations: Int = 4
    ) {
      // Set up the relaxations.
      var (red, black) = split(solution: solution)
      var relaxationDesc = RelaxationDescriptor()
      relaxationDesc.rightHandSide = rightHandSide
      
      for _ in 0..<iterations {
        // Gauss-Seidel: Red
        relaxationDesc.sweep = .red
        relaxationDesc.red = red
        relaxationDesc.black = black
        red = relax(descriptor: relaxationDesc)
        
        // Gauss-Seidel: Black
        relaxationDesc.sweep = .black
        relaxationDesc.red = red
        relaxationDesc.black = black
        black = relax(descriptor: relaxationDesc)
      }
      
      // Clean up after the relaxations.
      solution = merge(red: red, black: black)
    }
    
    func relax(descriptor: RelaxationDescriptor) -> [Float] {
      guard let sweep = descriptor.sweep,
            let red = descriptor.red,
            let black = descriptor.black,
            let rightHandSide = descriptor.rightHandSide else {
        fatalError("Descriptor was incomplete.")
      }
      
      // Allocate memory for the written solution values.
      var output = [Float](repeating: .zero, count: red.count)
      let gridSize = createGridSize(cellCount: rightHandSide.count)
      let h = createSpacing(gridSize: gridSize)
      
      // Determine whether to use Mehrstellen.
      let useMehrstellen = shouldUseMehrstellen(gridSize: gridSize)
      let edgePermutations = createEdgePermutations()
      
      // Iterate over the cells.
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Mask out either the red or black cells.
            let parity = indexX ^ indexY ^ indexZ
            let isRed = (parity & 1) == 0
            guard isRed == (sweep == .red) else {
              continue
            }
            
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(cellIndices, gridSize: gridSize)
            let (cellValue, residual) = convolutionKernel(
              sweep: sweep,
              red: red,
              black: black,
              solution: nil,
              rightHandSide: rightHandSide,
              
              gridSize: gridSize,
              h: h,
              useMehrstellen: useMehrstellen,
              edgePermutations: edgePermutations,
              cellIndices: cellIndices,
              cellAddress: cellAddress)
            
            let weight = useMehrstellen ? Float(-4) : Float(-6)
            let Δt: Float = (h * h) / weight
            output[cellAddress / 2] = cellValue + Δt * residual
          }
        }
      }
      return output
    }
    
    // The negative of b - Ax, which is Ax - b.
    func negativeResidual(
      solution: [Float], rightHandSide: [Float]
    ) -> [Float] {
      var output = [Float](repeating: .zero, count: solution.count)
      let gridSize = createGridSize(cellCount: solution.count)
      let h = createSpacing(gridSize: gridSize)
      
      // Determine whether to use Mehrstellen.
      let useMehrstellen = shouldUseMehrstellen(gridSize: gridSize)
      let edgePermutations = createEdgePermutations()
      
      // Iterate over the cells.
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(cellIndices, gridSize: gridSize)
            let (_, residual) = convolutionKernel(
              sweep: nil,
              red: nil,
              black: nil,
              solution: solution,
              rightHandSide: rightHandSide,
              
              gridSize: gridSize,
              h: h,
              useMehrstellen: useMehrstellen,
              edgePermutations: edgePermutations,
              cellIndices: cellIndices,
              cellAddress: cellAddress)
            
            output[cellAddress] = -residual
          }
        }
      }
      return output
    }
    
    // Execute the convolution kernel.
    @_transparent
    func convolutionKernel(
      sweep: Sweep?,
      red: [Float]?,
      black: [Float]?,
      solution: [Float]?,
      rightHandSide: [Float],
      
      gridSize: Int16,
      h: Float,
      useMehrstellen: Bool,
      edgePermutations: [SIMD3<Int16>],
      cellIndices: SIMD3<Int16>,
      cellAddress: Int
    ) -> (cellValue: Float, residual: Float) {
      // Iterate over the faces.
      var Lu: Float = .zero
      var f: Float = .zero
      for faceID in 0..<6 {
        let coordinateID = faceID / 2
        let coordinateShift = (faceID % 2 == 0) ? -1 : 1
        
        // Locate the neighboring cell.
        var neighborIndices = cellIndices
        neighborIndices[coordinateID] += Int16(coordinateShift)
        guard all(neighborIndices .>= 0),
              all(neighborIndices .< gridSize) else {
          continue
        }
        let neighborAddress = createAddress(
          neighborIndices, gridSize: gridSize)
        
        // Read the neighbor value from memory.
        var neighborValue: Float
        if sweep == .red {
          neighborValue = black.unsafelyUnwrapped[neighborAddress / 2]
        } else if sweep == .black {
          neighborValue = red.unsafelyUnwrapped[neighborAddress / 2]
        } else {
          neighborValue = solution.unsafelyUnwrapped[neighborAddress]
        }
        let weight = useMehrstellen ? Float(1.0 / 3) : Float(1)
        Lu += weight / (h * h) * neighborValue
        
        // Read the RHS value from memory.
        if useMehrstellen {
          f += Float(1.0 / 12) * rightHandSide[neighborAddress]
        }
      }
      
      // Iterate over the edges.
      if useMehrstellen {
        for edgePermutation in edgePermutations {
          // Locate the neighboring cell.
          var neighborIndices = cellIndices
          neighborIndices &+= edgePermutation
          guard all(neighborIndices .>= 0),
                all(neighborIndices .< gridSize) else {
            continue
          }
          let neighborAddress = createAddress(
            neighborIndices, gridSize: gridSize)
          
          // Read the neighbor value from memory.
          var neighborValue: Float
          if sweep == .red {
            neighborValue = red.unsafelyUnwrapped[neighborAddress / 2]
          } else if sweep == .black {
            neighborValue = black.unsafelyUnwrapped[neighborAddress / 2]
          } else {
            neighborValue = solution.unsafelyUnwrapped[neighborAddress]
          }
          Lu += Float(1.0 / 6) / (h * h) * neighborValue
        }
      }
      
      // Read the cell value from memory.
      var cellValue: Float
      if sweep == .red {
        cellValue = red.unsafelyUnwrapped[cellAddress / 2]
      } else if sweep == .black {
        cellValue = black.unsafelyUnwrapped[cellAddress / 2]
      } else {
        cellValue = solution.unsafelyUnwrapped[cellAddress]
      }
      do {
        let weight = useMehrstellen ? Float(-4) : Float(-6)
        Lu += weight / (h * h) * cellValue
      }
      
      // Read the RHS value from memory.
      do {
        let weight = useMehrstellen ? Float(1.0 / 2) : Float(1)
        f += weight * rightHandSide[cellAddress]
      }
      
      // Return the residual and cell value.
      let residual = f - Lu
      return (cellValue, residual)
    }
  }
}
