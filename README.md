# Splash30
My submission for the WWDC25 Swift Student Challenge. It is a basketball shooting analyzer and feedback app that uses your device's camera or recorded videos to track and evaluate your shots.

<img src="https://github.com/alpaycli/BasketballAnalyzer.swiftpm/blob/main/Assets.xcassets/appPreviewWithTrajectory.imageset/appPreviewWithTrajectory.png" width="500">

## Status
[Accepted](https://x.com/calalli24/status/1905308123977666957)

## Project Demo Video
[Demo Video](https://x.com/calalli24/status/1893307035933938008)

## Overview
The app offers 2+1 ways to analyze your shot:
- Real-time tracking using your device's camera
- Uploading recorded video
- Test mode with my recorded video to speed up the judgement process

Technologies I used on this project:

Vision DetectTrajectoryRequest - Used for detecting the ball’s trajectory on screen, seeing if the ball goes in or out and other analysis.

Vision DetectHumanBodyPoseRequest - Used for detecting the player’s position and body joints to calculate the release angle while shooting.

ReplayKit - Used for recording screen which makes possible to export the session in the end.

TextRenderer

MeshGradient

TipKit

AVFoundation

## Usage
Clone this repo. Downloding does not work properly due to it's being a .swiftpm project.

## Note
Last version of the project does not contain 'Hoop Detector' machine learning model due to size restrictions for the challenge, and only manual hoop selection is available.

You can find the version with the 'Hoop Detector' model in commits history.
