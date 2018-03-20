//

//  ViewController.swift
//  brightcoveintegrate
//
//  Created by Volodymyr Yevdokymov on 3/9/18.
//  Copyright © 2018 PrometheanTV. All rights reserved.
//

import UIKit
import BrightcovePlayerSDK
import PrometheanTVSDK

let Brightcove_account_id = "5687692865001"
let Brightcove_player = "default"

enum States {
    case playing
    case paused
    case stopped
}

class ViewController: UIViewController {

    //MARK: Outlets
    
    @IBOutlet weak fileprivate var videoContainerView: UIView!
    
    @IBOutlet weak fileprivate var prometheanChannelIdTF: UITextField!
    @IBOutlet weak fileprivate var videoIdTF: UITextField!
    
    @IBOutlet weak fileprivate var playBtn: UIButton!
    @IBOutlet weak fileprivate var pauseBtn: UIButton!
    @IBOutlet weak fileprivate var stopBtn: UIButton!
    
    var playerController = PrometheanTV.playerController
    var isPaused = false
    
    // BrightCove
    
    let bc_playbackService = BCOVPlaybackService(accountId: Brightcove_account_id, policyKey: brightcovePolicyKey())
    var bc_playbackController = BCOVPlayerSDKManager.shared().createPlaybackController()
    var bc_playerView: BCOVPUIPlayerView?
    
    //MARK: - Funcs
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.prometheanChannelIdTF.text = "5aa7d80fe7f165239829bba3"
        self.videoIdTF.text = "5743080499001"
        
        self.playerController.playbackDelegate = self
        
        self.updateControls(for: .stopped)
        
        let ima = brightcovePlayerIMA()
    }

    //MARK: - Actions
    
    @IBAction fileprivate func onPlayDidTap() {
        self.prepareBrightcove()
        self.requestContentFromPlaybackService()
    }

    @IBAction fileprivate func onPauseDidTap() {
        if self.isPaused {
            self.bc_playbackController?.play()
        } else {
            self.isPaused = true
            self.bc_playbackController?.pause()
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                self.updateControls(for: .paused)
            }
        }
    }
    
    @IBAction fileprivate func onStopDidTap() {
        self.bc_playbackController?.pause()
        self.isPaused = false
        self.bc_playerView?.removeFromSuperview()
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            self.updateControls(for: .stopped)
        }
    }
    
    @IBAction fileprivate func onPlayPTVDidTap() {
        if let ptvid = self.prometheanChannelIdTF.text {
            self.playerController.containerView = self.videoContainerView
            self.playerController.play(channelId: ptvid)
            self.playerController.isPlaybackControlsEnabled = true
        }
    }
    
    //MARK: - Helpers
    
    fileprivate func updateControls(for state:States) {
        self.pauseBtn.setTitle("Pause", for: .normal)

        switch state {
        case .stopped:
            self.playBtn.isEnabled = true
            self.pauseBtn.isEnabled = false
            self.stopBtn.isEnabled = false
        case .playing:
            self.playBtn.isEnabled = false
            self.pauseBtn.isEnabled = true
            self.stopBtn.isEnabled = true
        case .paused:
            self.playBtn.isEnabled = false
            self.pauseBtn.setTitle("Paused/Resume", for: .normal)
            self.pauseBtn.isEnabled = true
            self.stopBtn.isEnabled = true
        }
    }
    
    fileprivate func prepareBrightcove() {
        self.bc_playbackController?.delegate = self
        self.bc_playbackController?.isAutoAdvance = true
        self.bc_playbackController?.isAutoPlay = true
        self.bc_playerView = BCOVPUIPlayerView(playbackController: self.bc_playbackController, options: nil, controlsView: BCOVPUIBasicControlView.withVODLayout())
        
        // Install in the container view and match its size.
        if let view = self.bc_playerView {
            view.frame = self.videoContainerView.bounds
            view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            self.videoContainerView.addSubview(view)
        }
        self.playerController.containerView = self.bc_playerView?.controlsStaticView
        self.playerController.isPlaybackControlsEnabled = false
    }
    
    fileprivate func requestContentFromPlaybackService() {
        self.bc_playbackService?.findVideo(withVideoID: self.videoIdTF?.text ?? "", parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            if let v = video {
                self.bc_playbackController?.setVideos([v] as NSArray)
            } else {
                print("\(#function) - Error retrieving video: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
}

fileprivate func brightcovePolicyKey() -> String? {
    if let data = brightcovePlayerConfig(), let object = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String : Any] {
        let config = BrightcovePlayerConfig(JSON: object)
        return config?.policyKey
    }
    return nil
}

fileprivate func brightcovePlayerIMA() -> String? {
    if let data = brightcovePlayerConfig(), let object = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String : Any] {
        let config = BrightcovePlayerConfig(JSON: object)
        return config?.imaServerUrl
    }
    return nil
}

fileprivate func brightcovePlayerConfig() -> Data? {
    let policyKeyUrl = "https://players.brightcove.net/\(Brightcove_account_id)/\(Brightcove_player)_default/config.json"
    if let url = URL(string: policyKeyUrl), let data = try? Data(contentsOf: url) {
        return data
    }
    return nil
}


extension ViewController: BCOVPlaybackControllerDelegate{
    func playbackController(_ controller: BCOVPlaybackController!, didAdvanceTo session: BCOVPlaybackSession!) {
        print("Advanced to new session")
    }
    
    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didProgressTo progress: TimeInterval) {
        print("Progress: \(progress) seconds")

    }
    
    func playbackController(_ controller: BCOVPlaybackController!, didCompletePlaylist playlist: NSFastEnumeration!) {
        self.updateControls(for: .stopped)
        self.playerController.stop()
    }
    
    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didReceive lifecycleEvent: BCOVPlaybackSessionLifecycleEvent!) {
        if let type = lifecycleEvent.eventType {
            print("\(#function) - \(type)")
            switch type {
            case kBCOVPlaybackSessionLifecycleEventPlay:
                if !self.isPaused {
                    self.updateControls(for: .playing)
                }
                self.isPaused = false
                if let ptvid = self.prometheanChannelIdTF.text {
                    self.playerController.play(channelId: ptvid, src: nil, platformType: PTVPlatformType.overlaysOnly)
                }
            case kBCOVPlaybackSessionLifecycleEventEnd:
                self.updateControls(for: .stopped)
                self.playerController.stop()
                self.playerController.containerView = nil
            case "kBCOVPlaybackSessionLifecycleEventPauseRequest":
                self.isPaused = true
                self.updateControls(for: .paused)
//                self.playerController.pause()
            default:
                break
            }
        }
    }
}

extension ViewController: PTVPlayerPlaybackProtocol {
    func player(didChangeToState state: PTVPlayerState) {
        
    }
    
    func player(didPlayTime playTime: Float) {
        
    }
    
    func player(error: PTVPlayerError, description: String?) {
        
    }
    
    func player(didChangeNetworkConnection available: Bool) {
        
    }
    
    func playerShouldContinuePlaybackWhenNetworkConnectionGoesBack() -> Bool {
        return true
    }
    
    
}

