# STARSDK

> #### Moved to DP-3T!
> 
> As of May 2020, all of our efforts are transitioning to [DP-3T](https://github.com/DP-3T).
> 

## Introduction
This is the iOS version of the Secure Tag for Approach Recognition (STAR) SDK. The idea of the sdk is, to provide a SDK, which enables an easy way to provide methods for contact tracing. This project was built within 71 hours at the HackZurich Hackathon 2020.

## Architecture
There exists a central discovery server on [Github](https://raw.githubusercontent.com/SecureTagForApproachRecognition/discovery/master/discovery.json). This server provides the necessary information for the SDK to initialize itself. After the SDK loaded the base url for its own backend it will load the infected list from there, as well as post if a user is infected.

The backend should hence gather all the infected list  from other backends and provide a collected list from all sources. As long as the keys are generated with the SDK we can validate them across different apps.

## Further Documentation

There exists a documentation repository in the [STAR](https://github.com/SecureTagForApproachRecognition) Organization. It includes Swager YAMLs for the backend API definitions, as well as some more technical details on how the keys are generated and how the validation mechanism works


## Documentation
Please find in the project a Documentation folder with an **index.html** file.

## Installation
### Swift Package Manager

STARSDK is available through [Swift Package Manager][https://swift.org/package-manager]

1. Add the following to your `Package.swift` file:

  ```swift

  dependencies: [
      .package(url: "https://github.com/SecureTagForApproachRecognition/star-sdk-ios.git", branch: "master")
  ]

  ```
