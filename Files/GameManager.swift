//
//  GameManager.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 27.12.24.
//

import GameKit

class GameManager {
    
    class State: GKState {
        private(set) var validNextStates: [State.Type]
        
        init(_ validNextStates: [State.Type]) {
            self.validNextStates = validNextStates
            super.init()
        }
        
        func addValidNextState(_ state: State.Type) {
            validNextStates.append(state)
        }
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return validNextStates.contains(where: { stateClass == $0 })
        }
        
        override func didEnter(from previousState: GKState?) {
            let note = GameStateChangeNotification(newState: self, previousState: previousState as? State)
            note.post()
        }
    }
    
    class InactiveState: State {
    }
    
    class SetupCameraState: State {
    }
    
    class DetectingHoopState: State {
    }
    
    class DetectedHoopState: State {
    }

    class DetectingPlayerState: State {
    }
    
    class DetectedPlayerState: State {
    }

    class TrackShotsState: State {
    }
    
    class ShotCompletedState: State {
    }

    class ShowSummaryState: State {
    }

    fileprivate var activeObservers = [UIViewController: NSObjectProtocol]()
    
    let stateMachine: GKStateMachine
    var hoopRegion = CGRect.null
    var recordedVideoSource: AVAsset?
    var pointToMeterMultiplier = Double.nan
    var previewImage = UIImage()
    
    static var shared = GameManager()
    
    private init() {
        // Possible states with valid next states.
        let states = [
            InactiveState([SetupCameraState.self]),
            SetupCameraState([DetectingHoopState.self]),
            DetectingHoopState([DetectedHoopState.self]),
            DetectedHoopState([DetectingPlayerState.self, TrackShotsState.self]),
            DetectingPlayerState([DetectedPlayerState.self]),
            DetectedPlayerState([TrackShotsState.self]),
            TrackShotsState([ShotCompletedState.self, ShowSummaryState.self, DetectingHoopState.self]),
            ShotCompletedState([ShowSummaryState.self, TrackShotsState.self]),
            ShowSummaryState([DetectingPlayerState.self])
        ]
        // Any state besides Inactive can be returned to Inactive.
        for state in states where !(state is InactiveState) {
            state.addValidNextState(InactiveState.self)
//            states[0].addValidNextState(state.self)e
        }
        // Create state machine.
        stateMachine = GKStateMachine(states: states)
    }
    
    func reset() {
        // Reset all stored values
        hoopRegion = .null
        recordedVideoSource = nil
        pointToMeterMultiplier = .nan
        // Remove all observers and enter inactive state.
        let notificationCenter = NotificationCenter.default
        for observer in activeObservers {
            notificationCenter.removeObserver(observer)
        }
        activeObservers.removeAll()
        
        stateMachine.enter(InactiveState.self)
    }
}

protocol GameStateChangeObserver: AnyObject {
    func gameManagerDidEnter(state: GameManager.State, from previousState: GameManager.State?)
}

extension GameStateChangeObserver where Self: UIViewController {
    func startObservingStateChanges() {
        let token = NotificationCenter.default.addObserver(forName: GameStateChangeNotification.name,
                                                           object: GameStateChangeNotification.object,
                                                           queue: nil) { [weak self] (notification) in
            guard let note = GameStateChangeNotification(notification: notification) else {
                return
            }
            self?.gameManagerDidEnter(state: note.newState, from: note.previousState)
        }
        let gameManager = GameManager.shared
        gameManager.activeObservers[self] = token
    }
    
    func stopObservingStateChanges() {
        let gameManager = GameManager.shared
        guard let token = gameManager.activeObservers[self] else {
            return
        }
        NotificationCenter.default.removeObserver(token)
        gameManager.activeObservers.removeValue(forKey: self)
    }
}

struct GameStateChangeNotification {
    static let name = NSNotification.Name("GameStateChangeNotification")
    static let object = GameManager.shared
    
    let newStateKey = "newState"
    let previousStateKey = "previousState"

    let newState: GameManager.State
    let previousState: GameManager.State?
    
    init(newState: GameManager.State, previousState: GameManager.State?) {
        self.newState = newState
        self.previousState = previousState
    }
    
    init?(notification: Notification) {
        guard notification.name == Self.name, let newState = notification.userInfo?[newStateKey] as? GameManager.State else {
            return nil
        }
        self.newState = newState
        self.previousState = notification.userInfo?[previousStateKey] as? GameManager.State
    }
    
    func post() {
        var userInfo = [newStateKey: newState]
        if let previousState = previousState {
            userInfo[previousStateKey] = previousState
        }
        NotificationCenter.default.post(name: Self.name, object: Self.object, userInfo: userInfo)
    }
}

typealias GameStateChangeObserverViewController = UIViewController & GameStateChangeObserver

func getTestVideo() -> AVAsset? {
    guard let path = Bundle.main.path(forResource: "testVideo", ofType:"mp4") else {
        debugPrint("video.mp4 not found")
        return nil
    }
    let recordedVideo = AVAsset(url: URL(fileURLWithPath: path))
    print("GETTING TEST VIDEO")
    
    return recordedVideo
}
