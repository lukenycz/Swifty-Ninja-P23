//
//  GameScene.swift
//  Swifty-Ninja-P23
//
//  Created by Łukasz Nycz on 20/08/2021.
//

import SpriteKit
import AVFoundation

enum ForceBomb {
    case never, always, random
}
enum SequenceType: CaseIterable {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

class GameScene: SKScene {

    var gameScore: SKLabelNode!
    var endGameLabel: SKLabelNode!
    
    var score = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    var livesImage = [SKSpriteNode]()
    var lives = 3
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    
    var activeSlicePoints = [CGPoint]()
    
    var isSwooshSoundActive = false
    
    var activeEnemies = [SKSpriteNode]()
    var bombSoundEffect: AVAudioPlayer?
    
    var popupTime = 0.9
    var sequence = [SequenceType]()
    var sequencePosition = 0
    var chainDelay = 3.0
    var nextSequenceQueued = true
    
    var isGameEnded = false
    
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.zPosition = -1
        background.blendMode = .replace
        addChild(background)
        
        endGameLabel = SKLabelNode(fontNamed: "Chalkduster")
        endGameLabel.position = CGPoint(x: 512, y: 384)
        endGameLabel.horizontalAlignmentMode = .center
        endGameLabel.isHidden = true
        endGameLabel.fontColor = .systemRed
        
        addChild(endGameLabel)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlices()
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0...1000 {
            if let nextSequence = SequenceType.allCases.randomElement() {
                sequence.append(nextSequence)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            [weak self] in self?.tossEnemies()
        }
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        addChild(gameScore)
        gameScore.position = CGPoint(x: 8,y: 8)
        score = 0
    }
    func createLives() {
        for i in 0..<3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)),y:720)
            addChild(spriteNode)
            livesImage.append(spriteNode)
            
        }
    }
    func createSlices() {
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3
        
        activeSliceBG.strokeColor = .systemBlue
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard isGameEnded == false else {return}
            guard let touch = touches.first else { return}
            let location = touch.location(in: self)
            activeSlicePoints.append(location)
            redrawActiveSlice()
            
            if !isSwooshSoundActive {
                playSwooshSound()
            }
            let nodeAtPoint = nodes(at: location)
            for case let node as SKSpriteNode in nodeAtPoint {
                if node.name == "enemy" {
                    if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
                        emitter.position = node.position
                        addChild(emitter)
                    }
                    node.name = ""
                    node.physicsBody?.isDynamic = false
                    
                    let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                    let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                    let group = SKAction.group([scaleOut, fadeOut])
                    
                    let sequence = SKAction.sequence([group, .removeFromParent()])
                    node.run(sequence)
                    
                    score += 1
                    
                    if let index = activeEnemies.firstIndex(of: node) {
                        activeEnemies.remove(at: index)
                    }
                    run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                    
                } else if node.name == "bomb" {
                    guard let bombContainer = node.parent as? SKSpriteNode else {continue}
                    
                    if let emitter = SKEmitterNode(fileNamed: "sliceBomb") {
                        emitter.position = bombContainer.position
                        addChild(emitter)
                    }
                    node.name = ""
                    bombContainer.physicsBody?.isDynamic = false
                    
                    let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                    let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                    let group = SKAction.group([scaleOut, fadeOut])
                    
                    let sequence = SKAction.sequence([group, .removeFromParent()])
                    bombContainer.run(sequence)
                    
                    if let index = activeEnemies.firstIndex(of: bombContainer) {
                        activeEnemies.remove(at: index)
                    }
                    run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                    endGame(triggeredByBomb: true)
                } else if node.name == "enemyEvil" {
                    if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
                        emitter.position = node.position
                        addChild(emitter)
                    }
                    node.name = ""
                    node.physicsBody?.isDynamic = false
                    
                    let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                    let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                    let group = SKAction.group([scaleOut, fadeOut])
                    
                    let sequence = SKAction.sequence([group, .removeFromParent()])
                    node.run(sequence)
                    
                    score += 5
                    if let index = activeEnemies.firstIndex(of: node) {
                        activeEnemies.remove(at: index)
                    }
                    run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                }
        }
     }

    func endGame(triggeredByBomb: Bool) {
        guard isGameEnded == false else {return}
        isGameEnded = true
        physicsWorld.speed = 0.2
        isUserInteractionEnabled = false
        
        bombSoundEffect?.stop()
        bombSoundEffect = nil
        
    
        if triggeredByBomb {
            livesImage[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImage[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImage[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
        
        let frontground = SKSpriteNode(color: .darkGray, size: CGSize(width: 3000, height: 3000))
        frontground.alpha = 0.5
        frontground.zPosition = 3
        addChild(frontground)
        
        endGameLabel?.text = "END GAME"
        endGameLabel.isHidden = false
        endGameLabel = SKLabelNode(fontNamed: "Chalkduster")
        endGameLabel?.fontSize = 48
        endGameLabel.zPosition = 4
        endGameLabel?.position = CGPoint(x: 512,y: 384)
        
        
    }
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNumber = Int.random(in: 1...3)
        let soundName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        run(swooshSound) { [weak self] in self?.isSwooshSoundActive = false }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        redrawActiveSlice()
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        activeSliceFG.alpha = 1
        activeSliceBG.alpha = 1
    }
    
    func redrawActiveSlice() {
        if activeSlicePoints.count < 2 {
            activeSliceFG.path = nil
            activeSliceFG.path = nil
            return
        }
        if activeSlicePoints.count > 12 {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
        }
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        
        for i in 1 ..< activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    func createEnemy(forceBomb: ForceBomb = .random){
        let enemy: SKSpriteNode
        
            let enemyShuffle = Int.random(in: 0...6)
        
        var enemyType = enemyShuffle
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            
            if bombSoundEffect != nil {
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
                if let sound = try? AVAudioPlayer(contentsOf: path) {
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
                emitter.position = CGPoint(x: 76, y: 64)
                enemy.addChild(emitter)
            }
            
        } else if enemyType == 1 {
            enemy = SKSpriteNode(imageNamed: "penguinEvil")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemyEvil"
        
        } else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
                
            enemy.name = "enemy"
        }
        
            let positionShuffle = CGPoint(x: Int.random(in: 64...960), y: -128)
        let randomPosition = positionShuffle
        enemy.position = randomPosition
        
            let angularShuffle = CGFloat.random(in: -3...3)
        
        let randomAngularVelocity = angularShuffle
        let randomXVelocity: Int
        
        
        if randomPosition.x < 256 {
            let xShuffle = Int.random(in: 8...15)
            randomXVelocity = xShuffle
        } else if randomPosition.x < 512 {
            let xShuffle = Int.random(in: 3...5)
            randomXVelocity = xShuffle
        } else if randomPosition.x < 765 {
            let xShuffle = -Int.random(in: 3...5)
            randomXVelocity = xShuffle
        } else {
            let xShuffle = -Int.random(in: 8...15)
            randomXVelocity = xShuffle
        }
        let yShuffle = Int.random(in: 24...32)
        let randomYVelocity = yShuffle
        
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0
        
        addChild(enemy)
        activeEnemies.append(enemy)
        
        
    }
    func subtractLife() {
        lives -= 1
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        if lives == 2 {
            life = livesImage[0]
        } else if lives == 1 {
            life = livesImage[1]
        } else {
            life = livesImage[2]
            endGame(triggeredByBomb: false)
        }
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(by: 1, duration: 0.1))
    }
    override func update(_ currentTime: TimeInterval) {
        
        if activeEnemies.count > 0 {
            for (index, node) in activeEnemies.enumerated().reversed() {
                if node.position.y < -140 {
                    node.removeAllActions()
//                    node.removeFromParent()
//                    activeEnemies.remove(at: index)
                    if node.name == "enemy" || node.name == "enemyEvil" {
                        node.name = ""
                        subtractLife()
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                        
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    }
                }
            }
        } else  {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [weak self] in self?.tossEnemies()
                }
                nextSequenceQueued = true
            }
        }
        var bombCount = 0
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        if bombCount == 0 {
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
        
        
    }
        func tossEnemies() {
            guard isGameEnded == false else {return}

            popupTime *= 0.991
            chainDelay *= 0.99
            physicsWorld.speed *= 1.02
            
            let sequenceType = sequence[sequencePosition]
            
            switch sequenceType {
            case .oneNoBomb:
                createEnemy(forceBomb: .never)
            case .one:
                createEnemy()
            case .twoWithOneBomb:
                createEnemy(forceBomb: .never)
                createEnemy(forceBomb: .always)
            case .two:
                createEnemy()
                createEnemy()
            case .three:
                createEnemy()
                createEnemy()
                createEnemy()
            case .four:
                createEnemy()
                createEnemy()
                createEnemy()
                createEnemy()
            case .chain:
                createEnemy()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 5.0)
                { [weak self] in self?.createEnemy() }
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 5.0 * 2)
                { [weak self] in self?.createEnemy() }
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 5.0 * 3)
                { [weak self] in self?.createEnemy() }
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 5.0 * 4)
                { [weak self] in self?.createEnemy() }
            case .fastChain:
                createEnemy()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 10.0)
                { [weak self] in self?.createEnemy() }
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 10.0 * 2)
                { [weak self] in self?.createEnemy() }
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 10.0 * 3)
                { [weak self] in self?.createEnemy() }
                DispatchQueue.main.asyncAfter(deadline: .now() + chainDelay / 10.0 * 4)
                { [weak self] in self?.createEnemy() }

            }
            sequencePosition += 1
            nextSequenceQueued = false
        }
    }

