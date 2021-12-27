//
//  ViewController.swift
//  LoopSamplerDemo
//
//  Created by Joshua Teitelbaum on 12/26/21.
//

import UIKit
import Foundation
import AVKit

let DURATION_SLIDER_MAX = 30
let DURATION_SLIDER_MIN = 3
let HEIGHT_POINTS = 100
let TRANSPORT_VIEW_HEIGHT_POINTS = 50
let CLOCK_RECT_WIDTH = 5

protocol TimeQuery {
    func getTime() -> CMTime
}

protocol PercentageQuery {
    func getPercentage() -> Double
}

var timebaseInfo = mach_timebase_info_data_t()

func machAbsoluteToSeconds(machAbsolute: UInt64 = mach_absolute_time()) -> Double {
  let nanos = Double(machAbsolute * UInt64(timebaseInfo.numer)) / Double(timebaseInfo.denom)
  return nanos / 1.0e9;
}

class ClockView : UIView {
    var pq:PercentageQuery?
    
    init(pq:PercentageQuery) {
        super.init(frame: .zero)
        self.pq = pq
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        // 1
         guard let context = UIGraphicsGetCurrentContext() else {
           return
         }
        context.setFillColor(backgroundColor!.cgColor)
        context.fill(bounds)
        context.setFillColor(UIColor.red.cgColor)
        var percentage = pq?.getPercentage()
        
        if percentage == nil {
            return
        }
        if percentage! > 0.99  {
            percentage! = 0.99
        }
        let r = CGRect(x: bounds.width * CGFloat(percentage!), y: 0, width:  CGFloat(CLOCK_RECT_WIDTH), height: bounds.height)
         context.fill(r)
    }
}

class ViewController: UIViewController, TimeQuery, PercentageQuery {
    
    func getPercentage() -> Double {
        return 0
    }
    
    
    /// Very poor example here, but we're representing the clock :)
    ///   It will return the zero based offset from beginninng of marked start of loop
    ///   Obviously the resolution is "not good" but you could get it from say another Audio Visual source with a much better clock.
    func getTime() -> CMTime {
        return CMTime(seconds: machAbsoluteToSeconds(), preferredTimescale: 1)
    }
    

    var sampleButton:UIButton!
    var durationSlider:UISlider!
    var durationLabel:UILabel!
    var mediaLoopTimer:Timer!
    var mediaTimerStarted:CMTime!
    var mediaTimerFinished:CMTime!
    var simulatedClockTimer:Timer!
    var currentRecordedTime:CMTime!
    var clockView:ClockView!
    var recordButton:UIButton!
    var playButton:UIButton!
    var stopButton:UIButton!
    
    
    func addMediaDurationTimer() {
        mediaLoopTimer = Timer.scheduledTimer(timeInterval: TimeInterval(durationSlider.value), target: self, selector: #selector(simulatedMediatimerFunction), userInfo: nil, repeats: false)
        self.mediaTimerStarted = CMTime(seconds: machAbsoluteToSeconds(), preferredTimescale: 1)
    }
    func addSimulatedClockTimer() {
        simulatedClockTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(simulatedClocktimerFunction), userInfo: nil, repeats: true)
    }
    func addSampleButtons() {
        sampleButton = UIButton()
        sampleButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(sampleButton)
        sampleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        sampleButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        sampleButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        sampleButton.heightAnchor.constraint(equalToConstant: CGFloat(HEIGHT_POINTS)).isActive = true
        sampleButton.backgroundColor = .black
        sampleButton.setTitleColor(.white, for: .normal)
        sampleButton.setTitle("Air_Horn.mp3", for: .normal)
        sampleButton.addTarget(self, action: #selector(handleSlap(sender:)), for: .touchUpInside)
    }
    
    func addDurationText() {
        durationLabel = UILabel()
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(durationLabel)
        durationLabel.topAnchor.constraint(equalTo: sampleButton.safeAreaLayoutGuide.bottomAnchor).isActive = true
        durationLabel.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        durationLabel.rightAnchor.constraint(equalTo: sampleButton.safeAreaLayoutGuide.rightAnchor).isActive = true
        durationLabel.heightAnchor.constraint(equalToConstant: CGFloat(HEIGHT_POINTS)).isActive = true
        durationLabel.backgroundColor = .white
        durationLabel.textColor = .black
    }
    func addDurationSlider() {
        durationSlider = UISlider()
        durationSlider.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(durationSlider)
        durationSlider.topAnchor.constraint(equalTo: durationLabel.safeAreaLayoutGuide.bottomAnchor).isActive = true
        durationSlider.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        durationSlider.rightAnchor.constraint(equalTo: sampleButton.safeAreaLayoutGuide.rightAnchor).isActive = true
        durationSlider.heightAnchor.constraint(equalToConstant: CGFloat(HEIGHT_POINTS)).isActive = true
        durationSlider.backgroundColor = .black
        durationSlider.thumbTintColor = .white
        durationSlider.maximumValue = Float(DURATION_SLIDER_MAX)
        durationSlider.minimumValue = Float(DURATION_SLIDER_MIN)
        durationSlider.isContinuous = true
        durationSlider.layer.borderWidth = 2
        durationSlider.layer.borderColor = UIColor.red.cgColor
        
        durationSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)
        durationLabel.text = "Loop Length: \(durationSlider.value) seconds"
    }

    func addRecordPlayStopButtons() {
        let recordImage:UIImage = UIImage(systemName: "record.circle")!
        let playImage:UIImage = UIImage(systemName: "play")!
        let stopImage:UIImage = UIImage(systemName: "stop")!
        recordButton = UIButton()
        playButton = UIButton()
        stopButton = UIButton()
        
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        
        recordButton.setImage(recordImage, for: .normal)
        playButton.setImage(playImage, for: .normal)
        stopButton.setImage(stopImage, for: .normal)
        
        view.addSubview(recordButton)
        view.addSubview(playButton)
        view.addSubview(stopButton)
        
        recordButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        recordButton.topAnchor.constraint(equalTo: durationSlider.safeAreaLayoutGuide.bottomAnchor).isActive = true
        recordButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1/3.0).isActive = true
        recordButton.heightAnchor.constraint(equalToConstant: CGFloat(HEIGHT_POINTS)).isActive = true
        recordButton.addTarget(self, action: #selector(onRecordButtonPressed(sender:)), for: .touchUpInside)
        
        playButton.leftAnchor.constraint(equalTo: recordButton.safeAreaLayoutGuide.rightAnchor).isActive = true
        playButton.topAnchor.constraint(equalTo: durationSlider.safeAreaLayoutGuide.bottomAnchor).isActive = true
        playButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1/3.0).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: CGFloat(HEIGHT_POINTS)).isActive = true
        playButton.addTarget(self, action: #selector(onPlayButtonPressed(sender:)), for: .touchUpInside)
        
        stopButton.leftAnchor.constraint(equalTo: playButton.safeAreaLayoutGuide.rightAnchor).isActive = true
        stopButton.topAnchor.constraint(equalTo: durationSlider.safeAreaLayoutGuide.bottomAnchor).isActive = true
        stopButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1/3.0).isActive = true
        stopButton.heightAnchor.constraint(equalToConstant: CGFloat(HEIGHT_POINTS)).isActive = true
        stopButton.addTarget(self, action: #selector(onStopButtonPressed(sender:)), for: .touchUpInside)
    }
    
    @objc
    func onRecordButtonPressed(sender:Any) {
        
    }
    
    @objc
    func onPlayButtonPressed(sender:Any) {
        
    }
    @objc
    func onStopButtonPressed(sender:Any) {
        
    }
    
    func addClockView() {
        clockView = ClockView(pq: self)
        clockView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(clockView)
        clockView.topAnchor.constraint(equalTo: recordButton.safeAreaLayoutGuide.bottomAnchor).isActive = true
        clockView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        clockView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        clockView.heightAnchor.constraint(equalToConstant: CGFloat(TRANSPORT_VIEW_HEIGHT_POINTS)).isActive = true
        clockView.backgroundColor = .black
    }
    func stopLooper() {
        LoopSampler.shared.stopAllLoops()
    }
    
    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {
        self.durationLabel.text = "Loop Length: \(slider.value) seconds"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mach_timebase_info(&timebaseInfo)
        addSampleButtons()
        addDurationText()
        addDurationSlider()
        addRecordPlayStopButtons()
        addClockView()
        addSimulatedClockTimer()
    }

    @objc
    func handleSlap(sender: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            LoopSampler.shared.playSampleImmediate(sampleName: "Air_Horn.mp3")
        }
    }
    @objc func simulatedMediatimerFunction() {
        mediaTimerFinished = getTime()
        self.stopLooper()
    }
    @objc func simulatedClocktimerFunction() {
        if LoopSampler.shared.isPlayingOrRecording() {
            clockView.setNeedsDisplay()
        }
    }
}

