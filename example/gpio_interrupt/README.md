# GPIO Interrupt Application
Welcome to the `gpio_interrupt` AtomVM application.
### Usage:
- Create file:
``` sh
    rebar3 new lib interrupt
```
- Change `rebar.config` file:
``` sh
    {erl_opts, [debug_info]}.
    {deps, []}.
    {plugins, [
        atomvm_rebar3_plugin, erlfmt
    ]}.
```
### Activities:
- This application will wait in a loop for interrupt signals when GPIO pin 2 is rising.
- This pin is configured to be ordinarily pulled down.
- If you momentarily short pin 2 to a 3.3v source, the interrupt will be triggered on the rising side of the signal.
### Result:
- When we don't short pin 2 to a 3.3v source, the terminal show **"waiting for interrupt ..."**:
![](https://i.ibb.co/VYG823X/irq01.jpg)
- When we short pin 2 to a 3.3v source, the terminal show **"Interrupt on pin 2"**:
![](https://i.ibb.co/PQ6hZvJ/irq02.jpg)
