import XCTest

final class ElectrostaticsTests: XCTestCase {
  // This test defines the origin to the "center of charge", to have defined
  // behavior when the quadrupole depends on the origin:
  // https://phys.libretexts.org/Bookshelves/Mathematical_Physics_and_Pedagogy/Mathematical_Methods/The_Multipole_Expansion
  //
  // Also reproducing the octupole expansion. This has the best tradeoff
  // between computational overhead and improvement in quality:
  // https://physics.stackexchange.com/questions/269753/electric-octupole-moment-in-cartesian-coordinates
  //
  // For reference, the hexadecapole expansion is on this page (formula 19):
  //
  // https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7017380/
  func testMultipoleExpansion() throws {
    // Create a list of point charges, compute the multipole expansion, and
    // compare to results from direct integration. Show how the accuracy
    // improves from cutoff -> monopole -> dipole -> quadrupole -> octupole.
    
    // Program settings.
    let ionCharge: Int = 1
    let samplePosition: SIMD3<Float> = [-1.5, 0, 0]
    
    // Create the list of charges.
    var pointCharges: [SIMD4<Float>] = []
    pointCharges.append(SIMD4(-0.1, 0.2, 0.2, 7))
    for _ in 0..<2 {
      pointCharges.append(SIMD4(0.1, 0.2, 0, -1))
      pointCharges.append(SIMD4(-0.3, 0, -0.5, -1))
      pointCharges.append(SIMD4(-0.01, 0.4, 0.03, -1))
    }
    for _ in 0..<(1 - ionCharge) {
      pointCharges.append(SIMD4(0.3, 0.4, 0.5, -1))
    }
    
    // Find the origin of the multipole expansion.
    var origin: SIMD3<Float> = .zero
    var totalMass: Float = .zero
    for charge in pointCharges {
      let position = unsafeBitCast(charge, to: SIMD3<Float>.self)
      let mass = charge.w.magnitude
      origin += position * mass
      totalMass += mass
    }
    origin /= totalMass
    
    // Pre-compute some quantities.
    let r = samplePosition - origin
    let rNorm = (r * r).sum().squareRoot()
    let rHat = r / rNorm
    
    // Record each estimate to the electric potential, starting with 'cutoff'.
    var estimates: [Float] = []
    var potential: Float = .zero
    estimates.append(potential)
    
    // Compute the monopole expansion.
    do {
      var totalCharge: Float = .zero
      for charge in pointCharges {
        totalCharge += charge.w
      }
      potential += totalCharge / rNorm
    }
    estimates.append(potential)
    
    // Compute the dipole expansion.
    do {
      var dipoleMoment: SIMD3<Float> = .zero
      for charge in pointCharges {
        let position = unsafeBitCast(charge, to: SIMD3<Float>.self)
        let rPrime = position - origin
        dipoleMoment += charge.w * rPrime
      }
      let dotProduct = (rHat * dipoleMoment).sum()
      potential += dotProduct / (rNorm * rNorm)
    }
    estimates.append(potential)
    
    // Compute the quadrupole expansion.
    do {
      var quadrupoleMoment: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
      quadrupoleMoment = (.zero, .zero, .zero)
      
      for charge in pointCharges {
        let position = unsafeBitCast(charge, to: SIMD3<Float>.self)
        let rPrime = position - origin
        let r2 = (rPrime * rPrime).sum()
        
        var matrix: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
        matrix = (
          3 * rPrime.x * rPrime,
          3 * rPrime.y * rPrime,
          3 * rPrime.z * rPrime)
        matrix.0[0] -= r2
        matrix.1[1] -= r2
        matrix.2[2] -= r2
        
        quadrupoleMoment.0 += charge.w * matrix.0
        quadrupoleMoment.1 += charge.w * matrix.1
        quadrupoleMoment.2 += charge.w * matrix.2
      }
      
      let M_rHat = SIMD3(
        (quadrupoleMoment.0 * rHat).sum(),
        (quadrupoleMoment.1 * rHat).sum(),
        (quadrupoleMoment.2 * rHat).sum())
      let matrixProduct = 1 / 2 * (rHat * M_rHat).sum()
      potential += matrixProduct / (rNorm * rNorm * rNorm)
    }
    estimates.append(potential)
    
    // Compute the octupole expansion.
    do {
      var octupoleMoment: (
        (SIMD3<Float>, SIMD3<Float>, Float),
        (Void, SIMD3<Float>, Float),
        (Void, Void, Float))
      octupoleMoment = (
        (.zero, .zero, .zero),
        ((), .zero, .zero),
        ((), (), .zero))
      
      for charge in pointCharges {
        let position = unsafeBitCast(charge, to: SIMD3<Float>.self)
        let rPrime = position - origin
        let r2 = (rPrime * rPrime).sum()
        
        var tensor: (
          (SIMD3<Float>, SIMD3<Float>, Float),
          (Void, SIMD3<Float>, Float),
          (Void, Void, Float))
        tensor = (
          (15 * rPrime.x * rPrime.x * rPrime,
           15 * rPrime.x * rPrime.y * rPrime,
           15 * rPrime.x * rPrime.z * rPrime.z),
          ((),
           15 * rPrime.y * rPrime.y * rPrime,
           15 * rPrime.y * rPrime.z * rPrime.z),
          ((),
           (),
           15 * rPrime.z * rPrime.z * rPrime.z)
        )
        
        tensor.0.0 -= 3 * rPrime.x * r2
        tensor.0.0[0] -= 3 * rPrime.x * r2
        tensor.0.1[0] -= 3 * rPrime.x * r2
        // tensor.0.2[0] -= 3 * rPrime.x * r2
        tensor.0.0[0] -= 3 * rPrime.x * r2
        // tensor.1.0[0] -= 3 * rPrime.x * r2
        // tensor.2.0[0] -= 3 * rPrime.x * r2
        
        tensor.1.1 -= 3 * rPrime.y * r2
        // tensor.1.0[1] -= 3 * rPrime.y * r2
        tensor.1.1[1] -= 3 * rPrime.y * r2
        // tensor.1.2[1] -= 3 * rPrime.y * r2
        tensor.0.1[1] -= 3 * rPrime.y * r2
        tensor.1.1[1] -= 3 * rPrime.y * r2
        // tensor.2.1[1] -= 3 * rPrime.y * r2
        
        tensor.2.2 -= 3 * rPrime.z * r2
        // tensor.2.0[2] -= 3 * rPrime.z * r2
        // tensor.2.1[2] -= 3 * rPrime.z * r2
        tensor.2.2 -= 3 * rPrime.z * r2
        tensor.0.2 -= 3 * rPrime.z * r2
        tensor.1.2 -= 3 * rPrime.z * r2
        tensor.2.2 -= 3 * rPrime.z * r2
        
        octupoleMoment.0.0 += charge.w * tensor.0.0
        octupoleMoment.0.1 += charge.w * tensor.0.1
        octupoleMoment.0.2 += charge.w * tensor.0.2
        // octupoleMoment.1.0 += charge.w * tensor.1.0
        octupoleMoment.1.1 += charge.w * tensor.1.1
        octupoleMoment.1.2 += charge.w * tensor.1.2
        // octupoleMoment.2.0 += charge.w * tensor.2.0
        // octupoleMoment.2.1 += charge.w * tensor.2.1
        octupoleMoment.2.2 += charge.w * tensor.2.2
      }
      
      // Elimination of plane Z, row X.
      octupoleMoment.0.0[2] *= 2
      octupoleMoment.0.1[2] *= 2
      octupoleMoment.0.2 *= 2
      
      // Elimination of plane Z, row Y.
      octupoleMoment.0.1[2] *= 3 / 2
      octupoleMoment.1.1[2] *= 2
      octupoleMoment.1.2 *= 2
      
      // Elimination of plane Y, row X.
      octupoleMoment.0.0[1] *= 2
      octupoleMoment.0.1[1] *= 2
      octupoleMoment.0.1[2] *= 4 / 3
      
      // Partial elimination of row Z in each plane.
      octupoleMoment.0.0[2] *= 3 / 2
      octupoleMoment.0.1[2] *= 5 / 4
      octupoleMoment.0.1[2] *= 6 / 5
      octupoleMoment.1.1[2] *= 3 / 2
      octupoleMoment.0.2 *= 3 / 2
      octupoleMoment.1.2 *= 3 / 2
      
      // Redundantly compute the first element of row Y for simplicity.
      
      let T0_rHat = SIMD3(
        (octupoleMoment.0.0 * rHat).sum(),
        (octupoleMoment.0.1 * rHat).sum(),
        octupoleMoment.0.2 * rHat.z)
      let T1_rHat = SIMD3(
        0,
        (octupoleMoment.1.1 * rHat).sum(),
        octupoleMoment.1.2 * rHat.z)
      let T2_rHat = SIMD3(
        0,
        0,
        octupoleMoment.2.2 * rHat.z)
      let rHat_T_rHat = SIMD3(
        (rHat * T0_rHat).sum(),
        (rHat * T1_rHat).sum(),
        (rHat * T2_rHat).sum())
      let tensorProduct = 1 / 6 * (rHat * rHat_T_rHat).sum()
      potential += tensorProduct / (rNorm * rNorm * rNorm * rNorm)
    }
    estimates.append(potential)
    
    // Evaluate the potential directly.
    potential = .zero
    for charge in pointCharges {
      let position = unsafeBitCast(charge, to: SIMD3<Float>.self)
      let delta = samplePosition - position
      let deltaNorm = (delta * delta).sum().squareRoot()
      potential += charge.w / deltaNorm
    }
    estimates.append(potential)
    
    // Assert that each successive expansion has better quality.
    let actual = estimates.last!
    XCTAssertEqual(estimates[0], actual, accuracy: 0.83)
    XCTAssertEqual(estimates[1], actual, accuracy: 0.13)
    XCTAssertEqual(estimates[2], actual, accuracy: 0.06)
    XCTAssertEqual(estimates[3], actual, accuracy: 0.05)
    XCTAssertEqual(estimates[4], actual, accuracy: 0.01)
    
    XCTAssertNotEqual(estimates[0], actual, accuracy: 0.82)
    XCTAssertNotEqual(estimates[1], actual, accuracy: 0.12)
    XCTAssertNotEqual(estimates[2], actual, accuracy: 0.05)
    XCTAssertNotEqual(estimates[3], actual, accuracy: 0.04)
    XCTAssertNotEqual(estimates[4], actual, accuracy: 0.00)
  }
  
  
  
  // Analyze the case where a cell overlaps itself, and the explicit integral
  // for Hartree potential evaluates to infinity.
  //
  // The 1D case was calculated analytically, and it supposedly diverges.
  // - In the test below, the average value does eventually increase to
  //   infinity. The value scales with the logarithm of the number of grid
  //   points, but log(infinity) is still infinity.
  // The 2D case was calculated numerically: 2.9731896
  // The 3D case was calculated analytically: 2.3800774
  // Source: https://doi.org/10.1103/PhysRevB.50.11355
  //
  // v(r) = Σ ρ(r') g(r, r')
  // ijk ≠ i'j'k' | g(r, r') = h^3 / |r - r'|
  // ijk = i'j'k' | g(r, r') = -h^2 (π / 2 + 3 ln ((√3 - 1) / (√3 + 1)))
  func testSelfRepulsionIntegral1D() throws {
    // Try integrating the 1D and 2D integrals numerically.
    // 1) Exclude the singularities.
    // 2) Find the limit as the singularity becomes infinitesimally small.
    // 3) Take the average over the entire volume.
    let h: Float = 0.004
    let cellCount: Int = 250
    
    // Create an array that represents the charge density.
    //
    // Change the default value to check that the potential solver is correctly
    // responding to the input.
    let chargeDistribution = [Float](repeating: 1, count: cellCount)
    
    // Solve for the potential distribution with an integral.
    var potentialDistribution: [Float] = []
    for cellID in 0..<cellCount {
      let x = (Float(cellID) + 0.5) * h
      
      var accumulator: Double = .zero
      for otherCellID in 0..<cellCount where cellID != otherCellID {
        let otherX = (Float(otherCellID) + 0.5) * h
        
        // Integrate over 1D space.
        let ρ = chargeDistribution[otherCellID]
        let g = h / (x - otherX).magnitude
        accumulator += Double(ρ * g)
      }
      
      let v = Float(accumulator)
      potentialDistribution.append(v)
    }
    
    // Visualize the potential.
    do {
      let potentialLeft = potentialDistribution[0]
      let potentialLeft2 = potentialDistribution[1]
      let potentialCenter = potentialDistribution[cellCount / 2]
      let potentialRight2 = potentialDistribution[cellCount - 2]
      let potentialRight = potentialDistribution[cellCount - 1]
      XCTAssertEqual(potentialLeft, 6.0966754, accuracy: 1e-3)
      XCTAssertEqual(potentialLeft2, 7.092659, accuracy: 1e-3)
      XCTAssertEqual(potentialCenter, 10.811043, accuracy: 1e-3)
      XCTAssertEqual(potentialRight2, 7.0926757, accuracy: 1e-3)
      XCTAssertEqual(potentialRight, 6.0966783, accuracy: 1e-3)
    }
    
    // Report the average of the potential over the entire domain.
    do {
      var accumulator: Double = .zero
      for cellID in 0..<cellCount {
        let v = potentialDistribution[cellID]
        let drTerm = h
        accumulator += Double(v * drTerm)
      }
      
      let average = Float(accumulator)
      XCTAssertEqual(average, 10.201351, accuracy: 1e-3)
    }
  }
  
  func testSelfRepulsionIntegral2D() throws {
    let h: Float = 1.0 / 20
    let gridSize: Int = 20
    
    // Create an array that represents the charge density.
    let chargeGrid = [Float](repeating: 1, count: gridSize * gridSize)
    
    // Solve for the potential distribution with an integral.
    var potentialGrid: [Float] = []
    for indexY in 0..<gridSize {
      for indexX in 0..<gridSize {
        let x = (Float(indexX) + 0.5) * h
        let y = (Float(indexY) + 0.5) * h
        let cellID = indexY * gridSize + indexX
        
        var accumulator: Double = .zero
        for otherIndexY in 0..<gridSize {
          for otherIndexX in 0..<gridSize {
            let otherX = (Float(otherIndexX) + 0.5) * h
            let otherY = (Float(otherIndexY) + 0.5) * h
            let otherCellID = otherIndexY * gridSize + otherIndexX
            
            // Skip the singularity.
            if cellID == otherCellID {
              continue
            }
            
            // Find the distance between the two points.
            let r = SIMD2(x, y)
            let rPrime = SIMD2(otherX, otherY)
            let rDelta = r - rPrime
            let distance = (rDelta * rDelta).sum().squareRoot()
            
            // Integrate over 2D space.
            let ρ = chargeGrid[otherCellID]
            let g = (h * h) / distance
            accumulator += Double(ρ * g)
          }
        }
        
        let v = Float(accumulator)
        potentialGrid.append(v)
      }
    }
    
    // Visualize the potential.
    do {
      let size = gridSize
      
      let potential00 = potentialGrid[0 * size + 0]
      let potential01 = potentialGrid[0 * size + (size / 2)]
      let potential02 = potentialGrid[0 * size + (size - 1)]
      XCTAssertEqual(potential00, 1.8474634, accuracy: 1e-3)
      XCTAssertEqual(potential01, 2.427513, accuracy: 1e-3)
      XCTAssertEqual(potential02, 1.8474633, accuracy: 1e-3)
      
      let potential10 = potentialGrid[(size / 2) * size + 0]
      let potential11 = potentialGrid[(size / 2) * size + (size / 2)]
      let potential12 = potentialGrid[(size / 2) * size + (size - 1)]
      XCTAssertEqual(potential10, 2.427513, accuracy: 1e-3)
      XCTAssertEqual(potential11, 3.3281264, accuracy: 1e-3)
      XCTAssertEqual(potential12, 2.427513, accuracy: 1e-3)
      
      let potential20 = potentialGrid[(size - 1) * size + 0]
      let potential21 = potentialGrid[(size - 1) * size + (size / 2)]
      let potential22 = potentialGrid[(size - 1) * size + (size - 1)]
      XCTAssertEqual(potential20, 1.8474633, accuracy: 1e-3)
      XCTAssertEqual(potential21, 2.427513, accuracy: 1e-3)
      XCTAssertEqual(potential22, 1.8474633, accuracy: 1e-3)
    }
    
    // Report the average of the potential over the entire domain.
    //
    // This sequence converges:
    // size =   5 | 2.2688484 |
    // size =  10 | 2.6065936 | +0.3377452
    // size =  20 | 2.785188  | +0.1785944
    // size =  40 | 2.8777378 | +0.0925498
    // size =  80 | 2.9250371 | +0.0472993
    // size = 160 | 2.9489965 | +0.0239594
    // size = 320 | 2.961067  | +0.0120705
    // size = 640 | 2.9671283 | +0.0060613
    // size = inf | 2.9731896 |
    do {
      var accumulator: Double = .zero
      for cellID in 0..<gridSize * gridSize {
        let v = potentialGrid[cellID]
        let drTerm = h * h
        accumulator += Double(v * drTerm)
      }
      
      let average = Float(accumulator)
      XCTAssertEqual(average, 2.785188, accuracy: 1e-3)
    }
  }
  
  // Some simulations could require Neumann boundaries along the border of the
  // integration grid. If one sums the flux at each point along the boundary,
  // they should find that the divergence theorem has been violated. The
  // violation comes from discretization error.
  //
  // This test case examines how to correct for the error, restoring charge
  // conservation and solvability.
  //
  // Results:
  //
  // In two dimensions, Gauss's Law does not hold. However, this test shows a
  // procedure for summing fluxes across boundaries. When the code is used in
  // another application, the user should extend it to 3D and check that
  // Gauss's Law is upheld.
  func testNeumannBoundaries() throws {
    // The nucleus appears in the center of the grid. Its charge is +1.
    let h: Float = 0.05
    let gridSize: Int = 20
    
    // Create an array that represents the charge density (ρ).
    var chargeGrid = [Float](repeating: .zero, count: gridSize * gridSize)
    guard gridSize % 2 == 0 else {
      fatalError("The number of cells must be even.")
    }
    
    // Utility function for locating the four center cells.
    func createCenterCellIndices() -> [Int] {
      var cellIndices: [Int] = []
      let size = gridSize
      cellIndices.append((size / 2 - 1) * size + (size / 2 - 1))
      cellIndices.append((size / 2 - 1) * size + (size / 2))
      cellIndices.append((size / 2) * size + (size / 2 - 1))
      cellIndices.append((size / 2) * size + (size / 2))
      return cellIndices
    }
    
    // Divide the charge among four cells in the center.
    do {
      let totalCharge = Float(1)
      let chargePerCell = totalCharge / 4
      let chargeDensity = chargePerCell / (h * h)
      
      let cellIndices = createCenterCellIndices()
      for cellID in cellIndices {
        chargeGrid[cellID] = chargeDensity
      }
    }
    
    // Create an array that represents the boundary values in each cell.
    //
    // Elements of the flux data structure:
    // - [0] = lower X face
    // - [1] = lower Y face
    // - [2] = upper X face
    // - [3] = upper Y face
    var fluxPointChargeGrid = [SIMD4<Float>](
      repeating: .zero, count: gridSize * gridSize)
    var fluxIntegralGrid = [SIMD4<Float>](
      repeating: .zero, count: gridSize * gridSize)
    for indexY in 0..<gridSize {
      // Skip some loop iterations to minimize execution time.
      var indicesX: [Int] = []
      if indexY == 0 || indexY == gridSize - 1 {
        for indexX in 0..<gridSize {
          indicesX.append(indexX)
        }
      } else {
        indicesX = [0, gridSize - 1]
      }
      
      for indexX in indicesX {
        // Create the coordinate offsets for each face.
        let faceOffsetsX: [Float] = [-0.5, 0.0, 0.5, 0.0]
        let faceOffsetsY: [Float] = [0.0, -0.5, 0.0, 0.5]
        var faceCenters: [SIMD2<Float>] = []
        for faceID in 0..<4 {
          var x = (Float(indexX) + 0.5) * h
          var y = (Float(indexY) + 0.5) * h
          x += faceOffsetsX[faceID] * h
          y += faceOffsetsY[faceID] * h
          
          // Group the X and Y coordinates into a vector.
          let center = SIMD2(x, y)
          faceCenters.append(center)
        }
        
        // Utility function to generate flux data structures.
        func createFlux(
          _ closure: (SIMD2<Float>) -> SIMD2<Float>
        ) -> SIMD4<Float> {
          // Determine the flux from the point charge model.
          var faceFluxes: [SIMD2<Float>] = []
          for faceID in 0..<4 {
            let faceCenter = faceCenters[faceID]
            let flux = closure(faceCenter)
            faceFluxes.append(flux)
          }
          
          // Gather the flux components normal to each surface.
          var flux: SIMD4<Float> = .zero
          flux[0] = -faceFluxes[0].x
          flux[1] = -faceFluxes[1].y
          flux[2] = faceFluxes[2].x
          flux[3] = faceFluxes[3].y
          return flux
        }
        
        // Determine the flux from the point charge model.
        let fluxPointCharge = createFlux { faceCenter in
          // Place the nucleus at the midpoint of the 2D grid.
          let nucleusPosition = 0.5 * SIMD2(repeating: Float(gridSize) * h)
          
          // Find the distance and direction from the nucleus.
          let rDelta = faceCenter - nucleusPosition
          let distance = (rDelta * rDelta).sum().squareRoot()
          
          // The potential is always positive, while the gradient is always
          // negative.
          let gradient = -1 / (distance * distance)
          
          // Return the flux.
          let direction = rDelta / distance
          return gradient * direction
        }
        
        // Determine the flux through numerical integration.
        let fluxIntegral = createFlux { faceCenter in
          // Formula for potential. The gradient is derived from this formula.
          // v(r) = Σ ρ(r') g(r, r')
          // ij ≠ i'j' | g(r, r') = h^2 / |r - r'|
          var accumulator: SIMD2<Float> = .zero
          
          // Integrate over the occupied cells.
          let cellIndices = createCenterCellIndices()
          for cellID in cellIndices {
            // Determine the cells' 2D position.
            let cellIndexX = cellID % gridSize
            let cellIndexY = cellID / gridSize
            let cellX = (Float(cellIndexX) + 0.5) * h
            let cellY = (Float(cellIndexY) + 0.5) * h
            let cellCenter = SIMD2(cellX, cellY)
            
            // Find the distance and direction from the cell.
            let rDelta = faceCenter - cellCenter
            let distance = (rDelta * rDelta).sum().squareRoot()
            
            // The potential is always positive, while the gradient is always
            // negative.
            let ρ = chargeGrid[cellID]
            let gradient = -ρ / (distance * distance)
            
            // Add the flux times the microvolume.
            let direction = rDelta / distance
            let fluxTerm = gradient * direction
            let drTerm = h * h
            accumulator += fluxTerm * drTerm
          }
          
          // Return the sum of the integration points.
          return accumulator
        }
        
        // Write to the location in the simulation grid.
        let cellID = indexY * gridSize + indexX
        fluxPointChargeGrid[cellID] = fluxPointCharge
        fluxIntegralGrid[cellID] = fluxIntegral
      }
    }
    
    // Integrate the fluxes along the domain boundaries.
    
    // First, sum the charge density across the grid. This should be +1, but
    // the formula integrates this explicitly. Plus, it will give some insight
    // into how to sum across a restricted subsection of the domain.
    do {
      var accumulator: Double = .zero
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          let cellID = indexY * gridSize + indexX
          let ρ = chargeGrid[cellID]
          let drTerm = h * h
          accumulator += Double(ρ * drTerm)
        }
      }
      
      let volumeIntegral = Float(accumulator)
      XCTAssertEqual(volumeIntegral, 1, accuracy: 1e-3)
    }
    
    // Second, sum the fluxes across each set of boundaries.
    func createSurfaceIntegral(fluxGrid: [SIMD4<Float>]) -> Float {
      var accumulator: Double = .zero
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          let cellID = indexY * gridSize + indexX
          let faceFluxes = fluxGrid[cellID]
          
          var F: Float = .zero
          if indexX == 0 {
            F += faceFluxes[0]
          }
          if indexY == 0 {
            F += faceFluxes[1]
          }
          if indexX == gridSize - 1 {
            F += faceFluxes[2]
          }
          if indexY == gridSize - 1 {
            F += faceFluxes[3]
          }
          
          let drTerm = h
          accumulator += Double(F * drTerm)
        }
      }
      
      // Cast the accumulator to single precision and return the result.
      let surfaceIntegral = Float(accumulator)
      return surfaceIntegral
    }
    
    // Result of analytical integration.
    let radius = 0.5 * Float(gridSize) * h
    let segment = -1 / (Float(2).squareRoot() * radius)
    let expectedIntegral = 8 * segment
    XCTAssertEqual(expectedIntegral, -11.314, accuracy: 1e-3)
    
    // Results of numerical integration (point charge).
    do {
      let actualIntegral = createSurfaceIntegral(fluxGrid: fluxPointChargeGrid)
      XCTAssertEqual(expectedIntegral, actualIntegral, accuracy: 1e-2)
    }
    
    // Results of numerical integration (flux generated by direct evaluation).
    do {
      let actualIntegral = createSurfaceIntegral(fluxGrid: fluxIntegralGrid)
      XCTAssertEqual(expectedIntegral, actualIntegral, accuracy: 1e-1)
    }
  }
}
