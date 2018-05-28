//
//  ViewController+ARSCNViewDelegate.swift
//  TestForARKitDemo
//
//  Created by Kinlive on 2018/5/26.
//  Copyright © 2018年 Kinlive. All rights reserved.
//

import ARKit


// MARK: - ================== ARSCNViewDelegate ==========
extension ViewController: ARSCNViewDelegate {

  /**
   实现此方法来为给定 anchor 提供自定义 node。

   @discussion 此 node 会被自动添加到 scene graph 中。
   如果没有实现此方法，则会自动创建 node。
   如果返回 nil，则会忽略此 anchor。
   @param renderer 将会用于渲染 scene 的 renderer。
   @param anchor 新添加的 anchor。
   @return 将会映射到 anchor 的 node 或 nil。
   */
  //    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
  //        return nil
  //    }

  /**
   将新 node 映射到给定 anchor 时调用。

   @param renderer 将会用于渲染 scene 的 renderer。
   @param node 映射到 anchor 的 node。
   @param anchor 新添加的 anchor。
   */
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

    guard let anchor = anchor as? ARPlaneAnchor else { return }

    serialQueue.async {
//      self.addPlane(node: node, anchor: planeAnchor)
      let plane = Plane(withAnchor: anchor, isHidden: false)
      self.planes[anchor.identifier] = plane
      node.addChildNode(plane)

      self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: anchor, planeAnchorNode: node)
    }


  }
  /**
   使用给定 anchor 的数据更新 node 时调用。

   @param renderer 将会用于渲染 scene 的 renderer。
   @param node 更新后的 node。
   @param anchor 更新后的 anchor。
   */
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let plane = planes[anchor.identifier] else { return }
    guard let anchor = anchor as? ARPlaneAnchor else { return }
    serialQueue.async {
      plane.update(anchor: anchor)
      self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: anchor, planeAnchorNode: node)
    }
    // When an anchor is updated we need to also update our 3D geometry too. For example
    // the width and height of the plane detection may have changed so we need to update
    // our SceneKit geometry to match that
    // anchor 更新后也需要更新 3D 几何体。例如平面检测的高度和宽度可能会改变，所以需要更新 SceneKit 几何体以匹配



  }


  /**
   从 scene graph 中移除与给定 anchor 映射的 node 时调用。

   @param renderer 将会用于渲染 scene 的 renderer。
   @param node 被移除的 node。
   @param anchor 被移除的 anchor。
   */
  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard let anchor = anchor as? ARPlaneAnchor else { return }

    // Nodes will be removed if planes multiple individual planes that are detected to all be
    // part of a larger plane are merged.
    // 如果多个独立平面被发现共属某个大平面，此时会合并它们，并移除这些 node
    serialQueue.async {
      self.planes.removeValue(forKey: anchor.identifier)
    }


  }

  /**
   将要用给定 anchor 的数据来更新时 node 调用。

   @param renderer 将会用于渲染 scene 的 renderer。
   @param node 即将更新的 node。
   @param anchor 被更新的 anchor。
   */
  func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
  }

  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

    updateFocusSquare()
    guard let _ = sceneView.session.currentFrame?.lightEstimate else { return }

    // TODO: - Put this on the screen.
//    NSLog("light estimate: %f", estimate.ambientIntensity)

    // Here you can now change the .intensity property of your lights
    // so they respond to the real world environment

  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)

    switch camera.trackingState {
    case .notAvailable:
      fallthrough
    case .limited:
      textManager.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
    case .normal:
      textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
    }
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    // Present an error message to the user
    guard let arError = error as? ARError else { return }

    let nsError = error as NSError
    var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
    if let recoveryOptions = nsError.localizedRecoveryOptions {
      for option in recoveryOptions {
        sessionErrorMsg.append("\(option).")
      }
    }

    let isRecoverable = (arError.code == .worldTrackingFailed)
    if isRecoverable {
      sessionErrorMsg += "\nYou can try resetting the session or quit the application."
    } else {
      sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
    }

    displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
  }

  func sessionWasInterrupted(_ session: ARSession) {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    textManager.blurBackground()
    textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
  }

  func sessionInterruptionEnded(_ session: ARSession) {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    textManager.unblurBackground()
    session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
    restartExperience(self)
    textManager.showMessage("RESETTING SESSION")
  }
}


// MARK: - SCNPhysicsContactDelegate.
extension ViewController: SCNPhysicsContactDelegate {
  func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

    // Here we detect a collision between pieces of geometry in the world, if one of the pieces
    // of geometry is the bottom plane it means the geometry has fallen out of the world. just remove it

    if
      let nodeAPhysicsBody = contact.nodeA.physicsBody,
      let nodeBPhysicsBody = contact.nodeB.physicsBody
    {
      let contactMask = nodeAPhysicsBody.categoryBitMask | nodeBPhysicsBody.categoryBitMask

      if contactMask == (CollisionCategory.bottom.rawValue | CollisionCategory.cube.rawValue) {
        if nodeAPhysicsBody.categoryBitMask == CollisionCategory.bottom.rawValue {
          contact.nodeB.removeFromParentNode()
        } else {
          contact.nodeA.removeFromParentNode()
        }
      }
    }

  }

  func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {

  }

  func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {

  }
}

