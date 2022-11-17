# Why Erlang in IoT and micro-controller
## What is Erlang
Erlang is a programming language that runs on the BEAM abstract machine, Erlang is a (mostly) faithful implementation of the actor model
	Declarative
	Concurrency
	Soft real-time
	Robustness
	Distribution
	Hot code loading
	External interfaces
	Portability

## What Erlang differ from other languages
What is different about these platforms (Erlang/Python/Java/C ..) is that because actors are single threaded, and because memory is not shared between actors, you never need to worry about concurrent access to your data structures. A single actor instance is the only entity that can interact with given structure in memory.

## Why Erlang in micro-controllers
So what does any of this have to do with programming on micro-controllers? I mean, Erlang/OTP and the BEAM ecosystem is known for implementation of robust, scalable server applications, the kind of software that runs on large multicore machines that reside in data centers or in the cloud. Micro-controllers are a long way away from that!

## Why Erlang in IoT
I think the BEAM is relevant to these IoT devices in principle ways:
- For one, the BEAM is a pre-emptive multi-tasking runtime. When an “actor” is running on the BEAM, it is allowed to run a pre-defined number of “reductions” (think of them as instructions). If the actor reaches that limit, the underlying BEAM will pre-empt the actor, and allow another actor to proceed on the CPU. In this way, multiple actors can run on a single CPU, without requiring intervention on the part of the programmer. As Joe Armstrong famously said, “multi-tasking on a single CPU is just a form of scheduling”.
- What makes Erlang/Elixer and the BEAM compelling is that code that is targeted for the BEAM can run on processors with one, two, or n-many cores without modification, and, if designed properly (which is not hard to do), can potentially scale linearly with the addition of CPUs to the application. (In fact, many Erlang/Elixer applications can run on multiple machines, making use of CPU cores on the network, not just on the local machine.)
This becomes even more interesting in the case of the ESP32 micro-controller, which has two execution cores. (It also has a third core, but that is used in low-power mode.) As micro-controllers become more sophisticated, their ability to make use of cores becomes more important to developers, and if an application can benefit from additional CPUs without any change to the binary or source code, then that makes the platform very compelling for anyone who wants to develop software for these devices for less bugs, with less headache, and ultimately, for less money.
- Another way in which the BEAM is relevant to IoT is that many of these devices, such as the ESP8266 and ESP32, are implemented with a native wireless networking stack, making them easy (and cheap) to network together. And what better platform than OTP, with built-in support for distribution, and where the programming model on a single device extends naturally to multiple devices on a network?

## What is the advantage of using Erlang or Elixir in microcontroller???
1) compiles faster than arduino
2) more natural way to model how these systems work - overlapping sensors with their own behavior, in a sense
3) i find Erlang to be very easy to write cuz there is no global state, so if there is a mistake, its in your function parameters ONLY (hard to explain but when you experience it you'll be like, oh snap..)
4) very networking friendly - much easier to write network-capable programs than in C++
5) feels a little more well structured than micropython.. my MP code becomes really messy really quickly
Besides the fast that it is just super fun one big one is that once the VM is flashed you can compile and upload your programs really fast.  There are a lot of networking and pattern matching things that become ridiculously easy.  It's still hard for me to explain really well, but once my brain adjusted to it I stared to think of a whole bunch of new possibilities... Tlack and Fred can probably give you a better sales pitch about some of the more technical features.

Fred, [04/03/2022 21:41]
Welcome @Blahblaahblaaa !  I think Winston and Tom covered most of the bases.  I think the way to look at AtomVM, as an implementation of the BEAM (and Erlang and Elixir, as languages that run on the VM) is as something closer to an operating system than what you would see in a normal application you'd program on, say, a Windows orUNIX machine.  As you have read, Erlang/Elixir are actor-based environments, what Joe Armstrong called concurrency-based.  And I think the choice of the word "process", despite the confusion it causes, is really quite apt.  An operating system is responsible for forking and executing processes, and to keep the state of each process separate.  This was, in fact, one of the early inventions of UNIX, as a "multi-user" system!  Similarly, AtomVM (and the Erlang Runtime System -- ERTS) is responsible for managing lightwaeight processes and keeping their memory spaces separate.  So there is no shared memory, like you would have in a traditional programming environment.  Instead, processes communicate via messages, analogously to OS signals.  Another job of an operating system is to interleave running processes on a CPU (or array of CPUs), and to pre-empt and time-slice processes so that everyone gets a fair shot at the CPU.  AtomVM does the same thing for lightweight processes.  It is, in essence, "a multi-tasking OS for your code," as they say.  (As I discover more and more about RTOS, I actually see Erlang and AtomVM as being more aligned withe programming model you use there, too.  Erlang processes are very analogous to RTOS tasks.)

Fred, [04/03/2022 21:48]
As far as the languages that run over the BEAM, yes, Erlang and Elixir are your best bets, with Erlang being slightly more supported, but only because we have not implemented many of the core Elixir libraries, which are designed to make programming on the BEAM slightly easier.  But AtomVM doesn't really care about the langauage.  All it knows is the VM instructions and other parts of the compiled BEAM files, so if you are using Erlang, Elixir, or LIST-flavored Erlang, or any other BEAM language, your only constraints should be whether the core libraries are available.

Fred, [04/03/2022 21:51]
Again, language bashing here, Erlang is actually historically pinned to Prolog, and a lot of developers have diffiultly understanding the concepts behind the language.  I think there is also a lot of silly revulsion to what is trivial syntactic issues, like capitalized variable names, or the lack of curly braces, having to pass objects as parameters (like C) a lot of the time, instead of using "accessors" and "mutators", or the lack of an "object oriented" way to define your own data structure.  Probabaly the lack of a strict type system is also problemmatic for a lot fo developers.  It doesn't allow a lot of the "drop down" programming you get in langauges like Java, where the IDEs keep close tabs on the type system.  You simply can't do that in Erlang, though you can get close.  A lot of the paradigms simply don't fit with the way programmers have been indoctrinated to think, which is unfortunate.

Fred, [04/03/2022 21:53]
I can't really speak much to Elixir, since I am not a regular user.  I understand it is "ruby inspired", and I have met a lot of Elixir developers who have entered the OTP community through their jobs as Ruby refugees.  It's no accident, I don't think, that Phoenix is one of the biggest motivations for using Elixir, and Elixir has certainly found a home in the middle tier of most web applications.

Fred, [04/03/2022 21:56]
I'd say as far as getting started, having Windows is going to be a bit of a handicap, since we have all been spoiled with our various UNIX development environments.  The sad truth is that unless you feel like contributing to the Windows port of AtomVM (which would be most welcome!!!), I think you will probably need to run a virtual machine on your Windows laptop, in order to get any appreciable progress.  You could try to use Docker Desktop for Windows, but there will definitely be challenges there.  (I use Docker on the Mac, and it's very different than using Docker on a Linux machine).  My recommendation, to start, would be to build a Linux image on Virtual Box, or something, and to map your USB ports to the the Linux VM.  I have done that with VMWare Fusion, but I am quite out of practice with that.

OTOH, because the VM is implemented in very portable C, and because we use CMake, and because the os abstraction layer is pretty clean, a Windows port would probably not be that hard.

## Reference
https://blog.dushin.net/2018/11/running-atomvm-on-macos-and-an-esp32/
https://blog.dushin.net/2018/11/why-erlang-is-relevant-to-iot/