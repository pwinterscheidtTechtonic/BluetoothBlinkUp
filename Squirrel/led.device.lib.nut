class DeviceLeds {

  ledTimer = null;
  state = false;

  // Led setup
  _blue_pin = null;
  _red_pin = null;
  _green_pin = null;

  function breatheRed() {_breatheLed(_red_pin);}
  function breatheBlue() {_breatheLed(_blue_pin);}
  function breatheGreen() {_breatheLed(_green_pin);}

  current = 0.0;
  addVal = 0.1;
  function _breatheLed(pin = null) {
    if (pin == null)
      return;

    if (ledTimer != null) {
          imp.cancelwakeup(ledTimer);
          ledTimer = null;
    }
    pin.write(current);
    current += addVal;
    
    if (current > 1.0) addVal = -0.1;
    if (current < 0.0) addVal = 0.1;
    
    // Run the next iteration of the loop in 50ms
    ledTimer = imp.wakeup(0.1, function() {_breatheLed(pin)}.bindenv(this));
  }

  // Led methods
  function blinkBlue() {
      if (ledTimer != null) {
          imp.cancelwakeup(ledTimer);
          ledTimer = null;
      }
      state = !state;
      _blue_pin.write(state ? 1.0 : 0.0);
      _green_pin.write(0);
      _red_pin.write(0);
      ledTimer = imp.wakeup(1, function() {blinkBlue()}.bindenv(this));
  }

  function blueOn() {
      _blue_pin.write(1.0);
      _green_pin.write(0);
      _red_pin.write(0);
  }

  function greenOn() {
    _blue_pin.write(0);
    _green_pin.write(1.0);
    _red_pin.write(0); 
  }

  function redOn() {
    _blue_pin.write(0);
    _green_pin.write(0);
    _red_pin.write(1.0); 
  }

  function allOff() {
    _blue_pin.write(0);
    _green_pin.write(0);
    _red_pin.write(0); 
  }

  constructor(){
    if (imp.info().type == "imp006") {
      _blue_pin = hardware.pinXB;
      _red_pin = hardware.pinR
      _green_pin = hardware.pinXA;
    } else {
      throw "This library does not support your board."
    }

    //_blue_pin.configure(DIGITAL_OUT, 0);
    //_red_pin.configure(DIGITAL_OUT, 0);
    //_green_pin.configure(DIGITAL_OUT, 0);
    // Configure PWM with a period of 0.002s and initial duty cyle of 1.0
    _blue_pin.configure(PWM_OUT, 0.002, 1.0);
    _red_pin.configure(PWM_OUT, 0.002, 1.0);
    _green_pin.configure(PWM_OUT, 0.002, 1.0);

    allOff();
  }

}