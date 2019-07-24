DNS Record Types
================

A Swift implementation of DNS Record Types.

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

## Credits

This library was written by [Bouke Haarsma](https://twitter.com/BoukeHaarsma).
