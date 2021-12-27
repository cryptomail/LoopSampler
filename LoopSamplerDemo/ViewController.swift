//
//  ViewController.swift
//  LoopSamplerDemo
//
//  Created by Joshua Teitelbaum on 12/26/21.
//

import UIKit

let DURATION_SLIDER_MAX = 30
let DURATION_SLIDER_MIN = 3
let HEIGHT_POINTS = 100
class ViewController: UIViewController {

    var sampleButton:UIButton!
    var durationSlider:UISlider!
    var durationLabel:UILabel!
    
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

    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {
        self.durationLabel.text = "Loop Length: \(slider.value) seconds"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSampleButtons()
        addDurationText()
        addDurationSlider()
    }

    @objc
    func handleSlap(sender: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            LoopSampler.shared.playSampleImmediate(sampleName: "Air_Horn.mp3")
        }
    }
}

