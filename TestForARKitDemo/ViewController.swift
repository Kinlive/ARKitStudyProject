//
//  ViewController.swift
//  TestForARKitDemo
//
//  Created by Kinlive on 2018/4/13.
//  Copyright © 2018年 Kinlive. All rights reserved.
//

import UIKit
import ARKit
import simd
import SceneKit


struct CollisionCategory {
  let rawValue: Int

  // 1 << 0 左移0格 => 0001 -> 0001
  static let bottom = CollisionCategory(rawValue: 1 << 0)
  // 1 << 1 左移1格 => 0001 -> 0010
  static let cube = CollisionCategory(rawValue: 1 << 1)
}

class ViewController: UIViewController {

  @IBOutlet weak var sceneView: ARSCNView!

  @IBOutlet weak var messagePanel: UIVisualEffectView!
  @IBOutlet weak var messageLabel: UILabel!

  @IBOutlet weak var restartExperienceButton: UIButton!


  var planes: [UUID : Plane] = [UUID : Plane]()

  var foodImages = [#imageLiteral(resourceName: "mc_food_1"), #imageLiteral(resourceName: "mc_food_2"), #imageLiteral(resourceName: "mc_food_3"), #imageLiteral(resourceName: "mc_food_4"), #imageLiteral(resourceName: "mc_food_5"), #imageLiteral(resourceName: "mc_food_6"), #imageLiteral(resourceName: "mc_dessert_1"), #imageLiteral(resourceName: "mc_dessert_2"), #imageLiteral(resourceName: "mc_dessert_3")]
  var currentFood: Int = 0
  var boxes: [SCNNode] = []

  // MARK: - ARKit Config Properties

  var screenCenter: CGPoint?

  let session = ARSession()
  let standardConfiguration: ARWorldTrackingConfiguration = {
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = .horizontal
    return configuration
  }()

  // MARK: - Virtual Object Manipulation Properties

  var dragOnInfinitePlanesEnabled = false
  var virtualObjectManager: VirtualObjectManager!

  // MARK: - Other Properties

  var textManager: TextManager!
  var restartExperienceButtonIsEnabled = true
  var focusSquare: FocusSquare?

  // MARK: - Queues

  let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")




  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.

    setupUIControls()
    setupScene()

//    addBox()
    setupGestureToSceneView()

  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
//    setupSession()

    UIApplication.shared.isIdleTimerDisabled = true

    if ARWorldTrackingConfiguration.isSupported {
      // Start the ARSession.
      resetTracking()
    } else {
      // This device does not support 6DOF world tracking.
      let sessionErrorMsg = "This app requires world tracking. World tracking is only available on iOS devices with A9 processor or newer. " +
      "Please quit the application."
      displayErrorMessage(title: "Unsupported platform", message: sessionErrorMsg, allowRestart: false)
    }
  }
  override func viewWillDisappear(_ animated: Bool) {

    super.viewWillDisappear(animated)
    //sceneView.session.pause()
    session.pause()
  }

  // MARK: - Reset tracking
  func resetTracking() {
    session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])

    textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT",
                                inSeconds: 7.5,
                                messageType: .planeEstimation)
  }

  // MARK: - Setup

  func setupUIControls() {
    textManager = TextManager(viewController: self)

    // Set appearance of message output panel
    messagePanel.layer.cornerRadius = 3.0
    messagePanel.clipsToBounds = true
    messagePanel.isHidden = true
    messageLabel.text = ""
  }

  func setupScene() {
    // Synchronize updates via the `serialQueue`.
    virtualObjectManager = VirtualObjectManager(updateQueue: serialQueue)
    virtualObjectManager.delegate = self

    // set up scene view
    sceneView.setup()
    sceneView.delegate = self
    sceneView.session = session
    // sceneView.showsStatistics = true
    sceneView.autoenablesDefaultLighting = true

    sceneView.scene.enableEnvironmentMapWithIntensity(25, queue: serialQueue)

    setupFocusSquare()

    DispatchQueue.main.async {
      self.screenCenter = self.sceneView.bounds.mid
    }
    planes = [:]
    boxes = []

    // For our physics interactions, we place a large node a couple of meters below the world
    // origin, after an explosion, if the geometry we added has fallen onto this surface which
    // is place way below all of the surfaces we would have detected via ARKit then we consider
    // this geometry to have fallen out of the world and remove it

    let bottomPlane = SCNBox(width: 1000, height: 0.5, length: 1000, chamferRadius: 0)

    let bottomMaterial = SCNMaterial()
    bottomMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.0)
    bottomPlane.materials = [bottomMaterial]

    let bottomNode = SCNNode(geometry: bottomPlane)

    bottomNode.position = SCNVector3Make(0, -10, 0)
    bottomNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
    bottomNode.physicsBody?.categoryBitMask = CollisionCategory.bottom.rawValue
    bottomNode.physicsBody?.contactTestBitMask = CollisionCategory.cube.rawValue

    sceneView.scene.rootNode.addChildNode(bottomNode)
    sceneView.scene.physicsWorld.contactDelegate = self
  }

  // MARK: - ==============Setup scene===========
/*
  private func setupScene() {

    sceneView.delegate = self
    // 显示统计数据（statistics）如 fps 和 时长信息
    sceneView.showsStatistics = true
    sceneView.autoenablesDefaultLighting = false


    sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints,
                              ARSCNDebugOptions.showWorldOrigin]
//    let scene = SCNScene()
//    sceneView.scene = scene

    planes = [:]
    boxes = []

    // For our physics interactions, we place a large node a couple of meters below the world
    // origin, after an explosion, if the geometry we added has fallen onto this surface which
    // is place way below all of the surfaces we would have detected via ARKit then we consider
    // this geometry to have fallen out of the world and remove it

    let bottomPlane = SCNBox(width: 1000, height: 0.5, length: 1000, chamferRadius: 0)

    let bottomMaterial = SCNMaterial()
    bottomMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.0)
    bottomPlane.materials = [bottomMaterial]

    let bottomNode = SCNNode(geometry: bottomPlane)

    bottomNode.position = SCNVector3Make(0, -10, 0)
    bottomNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
    bottomNode.physicsBody?.categoryBitMask = CollisionCategory.bottom.rawValue
    bottomNode.physicsBody?.contactTestBitMask = CollisionCategory.cube.rawValue

    sceneView.scene.rootNode.addChildNode(bottomNode)
    sceneView.scene.physicsWorld.contactDelegate = self
  }
 */
   // MARK: - ==============Setup session===========
  private func setupSession() {
    //Setup session.
    let configuration = ARWorldTrackingConfiguration()
    // 明确表示需要追踪水平面。设置后 scene 被检测到时就会调用 ARSCNViewDelegate 方法
    configuration.planeDetection = .horizontal
    //When sceneView.autoenablesDefaultLighting set to false, use this property to handle light.
    configuration.isLightEstimationEnabled = true
    sceneView.session.run(configuration)

  }


  // MARK: - =================Handle tap gesture.

  @objc func handleTapFrom(recognizer: UITapGestureRecognizer) {
     // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
    let tapPoint = recognizer.location(in: sceneView)
    if let result = sceneView.hitTest(tapPoint, types: .existingPlaneUsingExtent).first {
      let hitTranslation = result.worldTransform.translation

      if
        let focusSquarePosition = focusSquare?.lastPositionOnPlane,
        let focusSquareLength = focusSquare?.focusSquareSize {
          let focusPositionX = focusSquarePosition.x
          let focusPositionZ = focusSquarePosition.z

        let halfLength = focusSquareLength / 2

        let checkXLeft = hitTranslation.x >= (focusPositionX - halfLength)
        let checkXRight = hitTranslation.x <= (focusPositionX + halfLength)
        let checkZUp = hitTranslation.z >= (focusPositionZ - halfLength)
        let checkZBottom = hitTranslation.z <= (focusPositionZ + halfLength)

        // FIXME: - 需要找出可以用來判斷 focusSquare範圍內的算法,或是在點擊時只限制出現一個node,解決這問題.
        print("checkXLeft: \(checkXLeft), checkXRight: \(checkXRight), checkZUp: \(checkZUp), checkZBottom: \(checkZBottom)")
        if
          checkXLeft && checkXRight && checkZUp && checkZBottom
        {
          insetGeometry(hitResult: result)
        }
      }
    }
  }

  // MARK: - ===============Handle long press gesture.

  @objc func handleHoldFrom(recognizer: UILongPressGestureRecognizer) {
    if recognizer.state != .began {
      return
    }
    // Perform a hit test using the screen coordinates to see if the user pressed on
    // a plane.
    let holdPoint = recognizer.location(in: sceneView)

    if let result = sceneView.hitTest(holdPoint, types: .existingPlaneUsingExtent).first {
      DispatchQueue.main.async {
        self.explode(hitResult: result)
      }
    }

  }

  // MARK: - =======================Handle hide plane gesture.
  @objc func handleHidePlaneFrom(recognizer: UILongPressGestureRecognizer) {
    if recognizer.state != .began {
      return
    }
    // Hide all the planes
    for planeId in planes.keys {
      planes[planeId]?.hide()
    }
    // Stop detecting new planes or updating existing ones.
    if let configuration = sceneView.session.configuration as? ARWorldTrackingConfiguration {
      configuration.planeDetection = .init(rawValue: 0)
      sceneView.session.run(configuration)
    }

  }

  // MARK: - =================Explode with hitResult
  private func explode(hitResult: ARHitTestResult) {
    // For an explosion, we take the world position of the explosion and the position of each piece of geometry
    // in the world. We then take the distance between those two points, the closer to the explosion point the
    // geometry is the stronger the force of the explosion.

    // The hitResult will be a point on the plane, we move the explosion down a little bit below the
    // plane so that the goemetry fly upwards off the plane

    let explosionYOffset: Float = 0.1
    let hitResultColumn3 = hitResult.worldTransform.columns.3
    let position = SCNVector3Make(hitResultColumn3.x,
                                  hitResultColumn3.y - explosionYOffset,
                                  hitResultColumn3.z)

    // We need to find all of the geometry affected by the explosion, ideally we would have some
    // spatial data structure like an octree to efficiently find all geometry close to the explosion
    // but since we don't have many items, we can just loop through all of the current geoemtry
    for cubeNode in boxes {
      // The distance between the explosion and the geometry
      //計算cude 與 觸發位置hitTest點擊處的三圍xyz相差距離
      var distance = SCNVector3Make(cubeNode.worldPosition.x - position.x,
                                    cubeNode.worldPosition.y - position.y,
                                    cubeNode.worldPosition.z - position.z)
      //取得三圍空間裡 cube與hitTest的直線距離
      let len: Float = sqrt(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)

      // Set the maximum distance that the explosion will be felt, anything further than 2 meters from
      // the explosion will not be affected by any forces
      //設定影響範圍 2m
      let maxDistance: Float = 2
      //判斷每一個cube距離hitTest位置是否在影響範圍內
      var scale: Float = max(0, (maxDistance - len))

      // Scale the force of the explosion
      //按照觸發點與cube的位置去比例調整爆炸的力道, 同理距離大於2m的cube 爆炸力道便為0
      scale = scale * scale * 2

      // Scale the distance vector to the appropriate scale
      distance.x = distance.x / len * scale
      distance.y = distance.y / len * scale
      distance.z = distance.z / len * scale

      // Apply a force to the geometry. We apply the force at one of the corners of the cube
      // to make it spin more, vs just at the center
      cubeNode.physicsBody?.applyForce(distance,
                                       at: SCNVector3Make(0.05, 0.05, 0.05),
                                       asImpulse: true)
    }
  }


  /*
   Matrices are used to transform 3D coordinates. These include:
   Rotation (changing orientation)
   Scaling (size changes)
   Translation (moving position)
   */

  // MARK: - Inset geometry box.
  func insetGeometry(hitResult: ARHitTestResult) {
    let dimension: CGFloat = 0.05
    let cube = SCNBox(width: dimension, height: dimension, length: dimension
      , chamferRadius: 0)

    //Add mc food on cube.
    /*
    let material = SCNMaterial()

    let img = foodImages[currentFood]
    currentFood += 1
    if currentFood > foodImages.count - 1 {
      currentFood = 0
    }
    material.diffuse.contents = img
    let transparentMaterial = SCNMaterial()
    transparentMaterial.diffuse.contents = UIColor.white

    //Material 的六面, 從ar世界裡初始相機位置看出去的方向 [ 0: 正前方, 1: 右邊面, 2: 後邊, 3: 左邊面, 4: 下邊, 5: 正上方 ],若是已經移動過相機位置就不能再以這個做參考.
    cube.materials = [transparentMaterial, transparentMaterial, material, transparentMaterial,  transparentMaterial,  transparentMaterial]
    */

    let node = SCNNode(geometry: cube)



    // The physicsBody tells SceneKit this geometry should be
    // manipulated by the physics engine
    node.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: nil)
    node.physicsBody?.mass = 2.0
    node.physicsBody?.categoryBitMask = CollisionCategory.cube.rawValue

    
    // We insert the geometry slightly above the point the user tapped
    // so that it drops onto the plane using the physics engine
    let insertionYOffset: Float = 0.5


    node.position = SCNVector3Make(
      hitResult.worldTransform.columns.3.x,
      hitResult.worldTransform.columns.3.y + insertionYOffset,
      hitResult.worldTransform.columns.3.z)

    //加入spot light 效果
    /*
    let spotLightPosition = SCNVector3Make(hitResult.worldTransform.columns.3.x,
                                           hitResult.worldTransform.columns.3.y,
                                           hitResult.worldTransform.columns.3.z)
    insertSpotLight(position: spotLightPosition)
     */
    
    // Add the cube to the scene
    sceneView.scene.rootNode.addChildNode(node)

    // Add the cube to an internal list for book-keeping
    boxes.append(node)
  }


   // MARK: - ==============Add box or cube.===========
  /*
  func addBox(x: Float = 0, y: Float = 0, z: Float = -0.2) {

    let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
    let boxNode = SCNNode()

    let boxMaterial = SCNMaterial()
    boxMaterial.diffuse.contents = foodImages[currentFood]

    boxNode.geometry?.materials = [boxMaterial]
    boxNode.geometry = box
    boxNode.position = SCNVector3(x, y, z)

    //One function.
//    let scene = SCNScene()
//    scene.rootNode.addChildNode(boxNode)
//    sceneView.scene = scene

    //Two function.
    sceneView.scene.rootNode.addChildNode(boxNode)

  }
   */

   // MARK: - ==============Add gesture to scene view.===========
  func setupGestureToSceneView() {

//    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(withRecognizer:)))
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapFrom(recognizer:)))
    sceneView.addGestureRecognizer(tapGesture)

    // Press and hold will cause an explosion causing geometry in the local vicinity of the explosion to move
    let explosionGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldFrom(recognizer:)))
    explosionGestureRecognizer.minimumPressDuration = 0.5
    sceneView.addGestureRecognizer(explosionGestureRecognizer)


    //Hipe plane when two touches press on view.
    let hidePlaneGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHidePlaneFrom(recognizer:)))

    hidePlaneGestureRecognizer.minimumPressDuration = 1
    hidePlaneGestureRecognizer.numberOfTouchesRequired = 2
    sceneView.addGestureRecognizer(hidePlaneGestureRecognizer)

  }

  /*
   // MARK: - ==============Set tap gesture what to do.===========
  @objc func didTap(withRecognizer recognizer: UITapGestureRecognizer) {

    let tapLocation = recognizer.location(in: sceneView)
    let hitTestResult = sceneView.hitTest(tapLocation, options: nil)

    guard let node = hitTestResult.first?.node else {
      //If touch's location no box then will create one.
      let hitTestResultWithFeaturePoints = sceneView.hitTest(tapLocation, types: .featurePoint)
      if let hitTestResultWithFeaturePoints = hitTestResultWithFeaturePoints.first {
        let translation = hitTestResultWithFeaturePoints.worldTransform.translation
        addBox(x: translation.x, y: translation.y, z: translation.z)
      }
      return
    }
    node.removeFromParentNode()
  }
 */


  // MARK: - Insert spot light node to sceneView with every node.
  private func insertSpotLight(position: SCNVector3) {
    let spotLight = SCNLight()
    spotLight.type = SCNLight.LightType.spot
    spotLight.spotInnerAngle = 45
    spotLight.spotOuterAngle = 45

    let spotNode = SCNNode()
    spotNode.light = spotLight
    spotNode.position = position

    // By default the stop light points directly down the negative
    // z-axis, we want to shine it down so rotate 90deg around the
    // x-axis to point it down
    spotNode.eulerAngles = SCNVector3Make(-.pi / 2, 0, 0)
    sceneView.scene.rootNode.addChildNode(spotNode)

  }


  // MARK: - Focus Square

  func setupFocusSquare() {
    serialQueue.async {
      self.focusSquare?.isHidden = true
      self.focusSquare?.removeFromParentNode()
      self.focusSquare = FocusSquare()
      self.sceneView.scene.rootNode.addChildNode(self.focusSquare!)
    }

    textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
  }

  func updateFocusSquare() {
    guard let screenCenter = screenCenter else { return }

    DispatchQueue.main.async {
      var objectVisible = false
      for object in self.virtualObjectManager.virtualObjects {
        if self.sceneView.isNode(object, insideFrustumOf: self.sceneView.pointOfView!) {
          objectVisible = true
          break
        }
      }

      if objectVisible {
        self.focusSquare?.hide()
      } else {
        self.focusSquare?.unhide()
      }

      let (worldPos, planeAnchor, _) = self.virtualObjectManager.worldPositionFromScreenPosition(screenCenter,
                                                                                                 in: self.sceneView,
                                                                                                 objectPos: self.focusSquare?.simdPosition)
      if let worldPos = worldPos {
        self.serialQueue.async {
          self.focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
        }
        self.textManager.cancelScheduledMessage(forType: .focusSquare)
      }
    }
  }


  // MARK: - Error handling

  func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
    // Blur the background.
    textManager.blurBackground()

    if allowRestart {
      // Present an alert informing about the error that has occurred.
      let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
        self.textManager.unblurBackground()
//        self.restartExperience(self)
      }
      textManager.showAlert(title: title, message: message, actions: [restartAction])
    } else {
      textManager.showAlert(title: title, message: message, actions: [])
    }
  }

}



