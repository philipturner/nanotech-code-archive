//
//  ReflectorGeneration.swift
//
//
//  Created by Philip Turner on 4/6/24.
//

import Accelerate

// A configuration for a reflector generation.
struct ReflectorGenerationDescriptor {
  var source: UnsafePointer<Float>?
  var destination: UnsafeMutablePointer<Float>?
  var dimension: Int?
  
  @_transparent
  init() { }
}

// Creates a reflector that transforms the provided vector into [1, 0, 0, ...].
struct ReflectorGeneration {
  // In typical API usage, one does not access the object's properties.
  @discardableResult
  @_transparent
  init(descriptor: ReflectorGenerationDescriptor) {
    guard let source = descriptor.source,
          let destination = descriptor.destination,
          let dimension = descriptor.dimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Take the norm of the vector.
    var norm: Float = .zero
    for elementID in 0..<dimension {
      norm += source[elementID] * source[elementID]
    }
    norm.formSquareRoot()
    
    // Check for NANs.
    let oldSubdiagonal = source[0]
    let newSubdiagonal = norm * Float((oldSubdiagonal >= 0) ? -1 : 1)
    let epsilon: Float = 2 * .leastNormalMagnitude
    guard epsilon < newSubdiagonal.magnitude,
          epsilon < (newSubdiagonal - oldSubdiagonal).magnitude else {
      for elementID in 0..<dimension {
        destination[elementID] = .zero
      }
      return
    }
    
    // Predict the normalization factor.
    let tau = (newSubdiagonal - oldSubdiagonal) / newSubdiagonal
    let tauSquareRoot = tau.squareRoot()
    let scaleFactor = tauSquareRoot / (oldSubdiagonal - newSubdiagonal)
    
    // Write to the reflector.
    for elementID in 0..<dimension {
      let element = source[elementID]
      destination[elementID] = element * scaleFactor
    }
    destination[0] = tauSquareRoot
  }
}
