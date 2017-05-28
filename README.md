DNS Record Types
================

A Swift implementation of DNS Record Types. Used for example in mDNS /
NetService.

[![Build Status](https://travis-ci.org/Bouke/DNS.svg?branch=master)](https://travis-ci.org/Bouke/DNS)

## Usage

```swift
// Encoding a message
let request = Message(header: Header(response: false),
questions: [Question(name: "apple.com.", type: .pointer)])
let reqeustData = request.pack()

// Not shown here: send to DNS server over UDP, receive reply.

// Decoding a message
let responseData = Data()
let response = try Message.init(unpack: responseData)
print(response.answers.first)
```

## Credits

This library was written by [Bouke Haarsma](https://twitter.com/BoukeHaarsma).
