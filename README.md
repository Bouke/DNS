DNS Record Types
================

A Swift implementation of DNS Record Types. Used for example in mDNS /
NetService.

[![Build Status](https://travis-ci.org/Bouke/DNS.svg?branch=master)](https://travis-ci.org/Bouke/DNS)

## Usage

```swift
// Encoding a message
let request = Message(
    type: .query,
    questions: [Question(name: "apple.com.", type: .pointer)]
)
let requestData = try request.serialize()

// Not shown here: send to DNS server over UDP, receive reply.

// Decoding a message
let responseData = Data()
let response = try Message.init(deserialize: responseData)
print(response.answers.first)
```

## Installation

### Carthage (iOS/macOS)

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate DNS.framework into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "Bouke/DNS"
```

Run `carthage` to build the framework and drag the built `Monitored.framework` into your Xcode project.

## Credits

This library was written by [Bouke Haarsma](https://twitter.com/BoukeHaarsma).
