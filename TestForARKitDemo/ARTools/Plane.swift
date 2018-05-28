//
//  Plane.swift
//  TestForARKitDemo
//
//  Created by Kinlive on 2018/5/22.
//  Copyright © 2018年 Kinlive. All rights reserved.
//

import Foundation
import ARKit
import SceneKit

class Plane: SCNNode {

  var anchor: ARPlaneAnchor!
//  var planeGeometry: SCNPlane!
  var planeGeometry: SCNBox!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    //    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - ==New init== with physics cube and plane.
  init(withAnchor anchor: ARPlaneAnchor, isHidden hidden: Bool) {
    super.init()

    self.anchor = anchor

    let width: CGFloat = CGFloat(anchor.extent.x)
    let length: CGFloat = CGFloat(anchor.extent.z)

    // For the physics engine to work properly give the plane some height so we get interactions
    // between the plane and the gometry we add to the scene
    let planeHeight: Float = 0.01

    planeGeometry = SCNBox(width: width, height: CGFloat(planeHeight), length: length, chamferRadius: 0)

    // Instead of just visualizing the grid as a gray plane, we will render
    // it in some Tron style colours.
    let material = SCNMaterial()
//    let img = #imageLiteral(resourceName: "tron_grid")
    material.diffuse.contents = UIColor.clear//img

    // Since we are using a cube, we only want to render the tron grid
    // on the top face, make the other sides transparent
    let transparentMaterial = SCNMaterial()
    transparentMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.0)

    if hidden {
      planeGeometry.materials = [transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial]
    } else {
      planeGeometry.materials = [transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, material, transparentMaterial]
    }

    let planeNode = SCNNode(geometry: planeGeometry)

    // Since our plane has some height, move it down to be at the actual surface
    planeNode.position = SCNVector3Make(0,
                                        -planeHeight / 2,
                                        0)

    // Give the plane a physics body so that items we add to the scene interact with it
    planeNode.physicsBody = SCNPhysicsBody(type: .kinematic,
                                           shape: SCNPhysicsShape(geometry: planeGeometry, options: nil))

    setTextureScale()
    addChildNode(planeNode)
  }

  func update(anchor: ARPlaneAnchor) {
    let planeHeight: Float = 0.01
    // As the user moves around the extend and location of the plane
    // may be updated. We need to update our 3D geometry to match the
    // new parameters of the plane.
    planeGeometry.width = CGFloat(anchor.extent.x)
    planeGeometry.length = CGFloat(anchor.extent.z)

    // When the plane is first created it's center is 0,0,0 and the nodes
    // transform contains the translation parameters. As the plane is updated
    // the planes translation remains the same but it's center is updated so
    // we need to update the 3D geometry position
    position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)

    if let node = childNodes.first {
      //self.physicsBody = nil;
      node.physicsBody = SCNPhysicsBody(type: .kinematic,
                                        shape: SCNPhysicsShape(geometry: planeGeometry,
                                                               options: nil))
      setTextureScale()
    }
  }

  func setTextureScale() {
    let width = Float(planeGeometry.width)
    let height = Float(planeGeometry.height)

    // As the width/height of the plane updates, we want our tron grid material to
    // cover the entire plane, repeating the texture over and over. Also if the
    // grid is less than 1 unit, we don't want to squash the texture to fit, so
    // scaling updates the texture co-ordinates to crop the texture in that case
    let material = planeGeometry.materials[4]
    material.diffuse.contentsTransform = SCNMatrix4MakeScale(width, height, 1)
    material.diffuse.wrapS = .repeat
    material.diffuse.wrapT = .repeat

  }

  func hide() {
    let transparentMaterial = SCNMaterial()
    transparentMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.0)
    planeGeometry.materials = [transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial]
  }


  /* ===========Old init============
  init(withAnchor anchor: ARPlaneAnchor, isHidden hidden: Bool) {
    super.init()

    self.anchor = anchor

    planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))

    //Instead of just visualizing the grid as a gray plane, we will render
    // it in some Tron style colours.
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = UIImage(named: "tron_grid")
    planeGeometry.materials = [material]

    let planeNode = SCNNode(geometry: planeGeometry)
    planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)

    // Planes in SceneKit are vertical by default so we need to rotate 90degrees to match
    // planes in ARKit

    planeNode.transform = SCNMatrix4MakeRotation(Float(-.pi / 2.0), 1.0, 0.0, 0.0)

    setTextureScale()
    addChildNode(planeNode)
  }

  func update(anchor: ARPlaneAnchor) {
    // As the user moves around the extend and location of the plane
    // may be updated. We need to update our 3D geometry to match the
    // new parameters of the plane.
    // 随着用户移动，平面 plane 的 范围 extend 和 位置 location 可能会更新。
    // 需要更新 3D 几何体来匹配 plane 的新参数。

    planeGeometry.width = CGFloat(anchor.extent.x);
    planeGeometry.height = CGFloat(anchor.extent.z);

    // When the plane is first created it's center is 0,0,0 and the nodes
    // transform contains the translation parameters. As the plane is updated
    // the planes translation remains the same but it's center is updated so
    // we need to update the 3D geometry position
    // plane 刚创建时中心点 center 为 0,0,0，node transform 包含了变换参数。
    // plane 更新后变换没变但 center 更新了，所以需要更新 3D 几何体的位置

    position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
    setTextureScale()
  }

  func setTextureScale() {

    let width = Float(planeGeometry.width)
    let height = Float(planeGeometry.height)


    // As the width/height of the plane updates, we want our tron grid material to
    // cover the entire plane, repeating the texture over and over. Also if the
    // grid is less than 1 unit, we don't want to squash the texture to fit, so
    // scaling updates the texture co-ordinates to crop the texture in that case
    // 平面的宽度/高度 width/height 更新时，我希望 tron grid material 覆盖整个平面，不断重复纹理。
    // 但如果网格小于 1 个单位，我不希望纹理挤在一起，所以这种情况下通过缩放更新纹理坐标并裁剪纹理
    let material = planeGeometry.materials.first
    material?.diffuse.contentsTransform = SCNMatrix4MakeScale(width, height, 1)
    material?.diffuse.wrapS = .repeat
    material?.diffuse.wrapT = .repeat

  }
 ===================Old init ===========*/


}
