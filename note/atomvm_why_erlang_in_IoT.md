# What is Erlang
Erlang is a programming language that runs on the BEAM abstract machine, Erlang is a (mostly) faithful implementation of the actor model
	Declarative
	Concurrency
	Soft real-time
	Robustness
	Distribution
	Hot code loading
	External interfaces
	Portability

# What Erlang differ from other languages
What is different about these platforms (Erlang/Python/Java/C ..) is that because actors are single threaded, and because memory is not shared between actors, you never need to worry about concurrent access to your data structures. A single actor instance is the only entity that can interact with given structure in memory.

# Why Erlang in micro-controllers
So what does any of this have to do with programming on micro-controllers? I mean, Erlang/OTP and the BEAM ecosystem is known for implementation of robust, scalable server applications, the kind of software that runs on large multicore machines that reside in data centers or in the cloud. Micro-controllers are a long way away from that!

# Why Erlang in IoT
I think the BEAM is relevant to these IoT devices in principle ways:
- For one, the BEAM is a pre-emptive multi-tasking runtime. When an “actor” is running on the BEAM, it is allowed to run a pre-defined number of “reductions” (think of them as instructions). If the actor reaches that limit, the underlying BEAM will pre-empt the actor, and allow another actor to proceed on the CPU. In this way, multiple actors can run on a single CPU, without requiring intervention on the part of the programmer. As Joe Armstrong famously said, “multi-tasking on a single CPU is just a form of scheduling”.
- What makes Erlang/Elixer and the BEAM compelling is that code that is targeted for the BEAM can run on processors with one, two, or n-many cores without modification, and, if designed properly (which is not hard to do), can potentially scale linearly with the addition of CPUs to the application. (In fact, many Erlang/Elixer applications can run on multiple machines, making use of CPU cores on the network, not just on the local machine.)
This becomes even more interesting in the case of the ESP32 micro-controller, which has two execution cores. (It also has a third core, but that is used in low-power mode.) As micro-controllers become more sophisticated, their ability to make use of cores becomes more important to developers, and if an application can benefit from additional CPUs without any change to the binary or source code, then that makes the platform very compelling for anyone who wants to develop software for these devices for less bugs, with less headache, and ultimately, for less money.
- Another way in which the BEAM is relevant to IoT is that many of these devices, such as the ESP8266 and ESP32, are implemented with a native wireless networking stack, making them easy (and cheap) to network together. And what better platform than OTP, with built-in support for distribution, and where the programming model on a single device extends naturally to multiple devices on a network?

# Reference
https://blog.dushin.net/2018/11/running-atomvm-on-macos-and-an-esp32/
https://blog.dushin.net/2018/11/why-erlang-is-relevant-to-iot/