// Denne sketch, lavet på baggrund af Rebecca Fiebrinks Processing_SimpleColor_1Continuous,
// modtager en kontinuert variabel output-værdi fra Wekinator og sender det videre til en Arduino.
// Det gør det muligt at styre en række ting, eksempelvis en servomotor, nogle relæer eller lysdioder
// (binære), eller en PWM-styret komponent (motor med variabel hastighed, lysdiode med varierende 
// lysstyrke) fra Wekinator. Kommunikation foregår med OSC-beskeder - lige nu samles en enkelt 
// kontinuert variabel parameter op ("vinkel"), men flere kan føjes ind. 
// Der er gjort plads til inputs også i varablerne, men ikke lavet metoder til det. 
// Tanken er at have en generisk sketch som kan tilpasses efter behov.

// Arduinoen skal køre den sketch, der hedder StandardFirmata. Den findes i Arduino-interfacet 
// under Fil -> Eksempler -> Firmata. StandardFirmata skal ikke tilrettes på nogen måde.

// Processing behøver bibliotekerne nævnt udmiddelbart herunder

// Nødvendigt for OSC kommunickation med Wekinator:
import oscP5.*;
import netP5.*;

//Nødvendigt for at kommunikere med Arduinoen:
import processing.serial.*;
import cc.arduino.*;

// OSC-objektet, som modtager beskeder fra Wekinator
OscP5 oscP5;

// Wekinator-objektet, som i setup() får besked om hvad sketchen her forventer at få
NetAddress dest;

// Arduino-objektet, som skal modtage instruktioner fra denne sketch
Arduino arduino;

// Servoens parametre. Servoer kan bruge alle digitale pins
int servoPin = 7;
int servoAngle;
int formerAngle;
boolean retning;

int binaryInput;
int formerInput;

// Analog in/out. 
// Input sker over de analoge porte (A0-A5 på Uno'en).
// Output sker via PWM (Pulse Width Modulation)over de digitale porte, 
// der er markeret med en tilde (~), dvs. portene 3, 5, 6, 9, 10 og 11 
// på Uno'en. 
int analogSensorPin = 5; // Altså pin A5
int pwmPin = 11; 
int pwmValue;

// Digitalt in/out. Kan bruge alle digitale pins
int redPin = 6;
int greenPin = 2;
int knapPin = 4; 
int laasPin = 8;

PFont lilleFont, storFont;

void setup() {
  // Initialiserer OSC kommunikation
  dest = new NetAddress("192.168.8.103",11000); //send messages tilbage til Wekinator på localhost, port 6448 (din egen maskine) (default)
  oscP5 = new OscP5(this,10330); //lyt efter OSC messages på port 10330 (Wekinator default)
  sendOscNames();

  // Udskriver en liste over aktive serielle porte, så vi kan finde porten med Arduinoen
  println((Object[])Arduino.list());
  
  // Hvis du har flere serielle porte i gang, og hvis ikke Arduino'en sidder på den 
  // første af dem, så tilret denne linje ved at udskifte "0" med index-nummeret på den 
  // serielle port, som svarer til dit Arduino board (som det står i linjerne udskrevet
  // af kodelinjen ovenfor).
  arduino = new Arduino(this, Arduino.list()[0], 57600);
  
  // Alternativt kan du bruge navnet på den serielle port svarende til din
  // Arduino (i dobbelte anførselstegn), som i denne linje:
  //arduino = new Arduino(this, "/dev/tty.usbmodem621", 57600);
  
  // Konfigurer servoPin 
  arduino.pinMode(servoPin, Arduino.SERVO);
 
  // Konfigurer digitale LED-pins som binært output og knapPin som input
  arduino.pinMode(redPin, Arduino.OUTPUT);
  arduino.pinMode(greenPin, Arduino.OUTPUT);
  arduino.pinMode(knapPin, Arduino.INPUT);
  arduino.pinMode(laasPin, Arduino.OUTPUT);
  
  // Konfiguration af analoge pins er ikke nødvendig
  
  // Giv servoen nogle startværdier
  servoAngle = 30;
  formerAngle = 30;
  retning = true;
  
  // Giv PWM-outputtet en værdi
  pwmValue = 128;
  
  // Giv de digitale outputs nogle startværdier
  arduino.digitalWrite(redPin, Arduino.LOW);
  arduino.digitalWrite(greenPin, Arduino.LOW);
  arduino.digitalWrite(laasPin, Arduino.LOW);
  
  // Vindue til at beskrive servoens status i
  size(400, 400, P3D);
  smooth();
  background(220);

  // Initialiser skriftens udseende
  storFont = createFont("Arial", 44);
  lilleFont = createFont("Arial", 20);
}

void draw() {
  background(servoAngle); // Baggrundsfarven varierer med Wekinator-parameter[0]
  skrivText();
  drejServo();
  sendPWM(pwmValue); // Denne parameter er lige nu blot en dummy
}

// Denne metode kaldes automatisk, hver gang der modtages en ny OSC message
// Der kan findes flere værdier fra OSC meddelelsen (hvis der er nogen) 
// ved at spørge på flere index
void oscEvent(OscMessage theOscMessage) {
  println("   En OSC besked er modtaget" + theOscMessage.toString());
  if (theOscMessage.checkAddrPattern("/lock")==true) {
     // ser efter 1 kontrol værdi
     if(theOscMessage.checkTypetag("f")) { 
        println("Modtaget: ");
        float modtagetVal = theOscMessage.get(0).floatValue();
        formerAngle = servoAngle; // Gem den gamle værdi så vi kan finde servoens retning
        // Den modtagne værdi mellem 0 og 1 skal mappes til 0-180 grader og begrænses til det
        servoAngle = int(constrain((map(modtagetVal, 0, 1, 0, 180)), 0, 180));
        if (formerAngle != servoAngle) {
          if (formerAngle > servoAngle) retning = true;
          else retning = false;
        }
     } else if(theOscMessage.checkTypetag("i")) { 
        println("Modtaget: ");
        int modtagetVal = theOscMessage.get(0).intValue();
        formerInput = binaryInput; // Gem den gamle værdi så vi kan finde servoens retning
        // Den modtagne værdi mellem 0 og 1 skal mappes til 0-180 grader og begrænses til det
        binaryInput = modtagetVal;
        if (formerInput != binaryInput) {
          if (formerInput > binaryInput) retning = false;
          else retning = true;
        }
     } else {
        println("Fejl: Uventet OSC message modtaget af Processing: ");
        //theOscMessage.print();    
     }
   }
}

// Sender navnet på den aktuelle parameter (vinkel) til Wekinator. Gøres kun i setup()
void sendOscNames() {
  OscMessage msg = new OscMessage("/wekinator/control/setOutputNames");
  msg.add("vinkel"); 
  oscP5.send(msg, dest);
  println("  Noget er sendt til wek");
}

// Skriv instruktioner og wekinator output på skærmen
void skrivText() {
    stroke(0, 0, 255);
    textFont(lilleFont);
    textAlign(LEFT, TOP); 
    //fill(0, 0, 255);
    text("Modtager 1 kontinuert parameter: vinkel", 10, 40);
    text("Lytter efter /wek/outputs paa port 10330", 10, 10);
    stroke(255, 100, 0);
    textFont(storFont);
    textAlign(LEFT, TOP); 
    text("Vinkel: " + str(servoAngle) + " grader", 40, 200);
    text("Retning: " + str(retning), 40, 250);
}

// Drej servoen
void drejServo() {
  arduino.servoWrite(servoPin, servoAngle);
  //lysLED(retning); // retning angiver om servoAngle vokser (true) eller aftager (false)
  sendDig(retning);
}

// Sender et (næsten) analogt signal, dvs. en værdi, som skal ligge i intervallet 0-255 
// Kan bruges til at styre hastigheden på en motor, lysstyrken på en pære etc.
void sendPWM(int value) {
  arduino.analogWrite(pwmPin, value);
}

// Styr en lås, en ventil, et relæ eller lignende
void sendDig(boolean positiv) {
  if (positiv) {
    arduino.digitalWrite(laasPin, Arduino.HIGH); // Låsen er åben
  } else {
    arduino.digitalWrite(laasPin, Arduino.LOW); // Låsen er låst
  }
  lysLED(positiv);
}

// Få dioderne til at lyse. Grøn lyser hvis der modtages true, ellers lyser rød
void lysLED(boolean positiv) {
  if(positiv) {
    arduino.digitalWrite(redPin, Arduino.LOW);
    arduino.digitalWrite(greenPin, Arduino.HIGH);
  } else {
    arduino.digitalWrite(redPin, Arduino.HIGH);
    arduino.digitalWrite(greenPin, Arduino.LOW);
  }
}
