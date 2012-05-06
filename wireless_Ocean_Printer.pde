#include <EEPROM.h>

/************************************************************
Alex Hornstein
Wireless Twitter Printer
5.6.12
an Ocean Invention project


This project is a small printer that connects to the internet over wifi,
grabs the latest tweets on a topic of your choosing, and prints them out
on a strip of paper.  The printer is just like the receipt printers at 
7/11.  It uses rolls of thermal paper that you can get at any office supply store

I used the wifly shield because it's awesome.  It worked
right out of the box for me, and now the only cable going to my project is a small power cord from
a wall wart.  With a couple D batteries, you could totally make this thing battery-powered, too.  Oooh!
Or solar!

The total project cost me $130, not counting the arduino.  I've printed out hundreds of feet of tweets, and still counting!

I originally made this printer as a collaboration tool between my new lab in Manila and our partner lab in Hong Kong, so we could
share ideas in a way that was cooler and more engaging than email.  The plan was to stick one of these printers on the ceiling of 
anyone we're working with, and whenever anyone had an idea they wanted to share, they'd tweet it with the hashtag #oceanInvention 
(that's our network of invention labs).  The idea would then instantly print out from all the printers, all over the world.

Since I was using twitter as a back-end for the project, I decided I might as well make the printer a generic tweet-printer.  
I wanted to make it easy to change the twitter topic that the printer prints out, so I gave each printer a unique name and made a 
website where you enter a topic for your printer (at artiswrong.com/oceanPrinter)



Here's all the parts you need:
++ Thermal printer, $50 from sparkfun (http://www.sparkfun.com/products/10438) or adafruit (https://www.adafruit.com/products/597)

++ Wifly wireless internet shield, $80 from sparkfun (http://www.sparkfun.com/products/9954)

++ Arduino.  I used a seeeduino duemilanove clone with an atmega328, but an uno would work fine as well.  I would stick to processors with a atmega328
processor or better.  Grab one from adafruit(https://www.adafruit.com/products/50) or sparkfun(http://www.sparkfun.com/products/10356) or seeed studios(http://www.seeedstudio.com/depot/seeeduino-v30-atmega-328p-p-669.html?cPath=132_133) for ~$30

++  Stackable arduino header kit.  The wifly shield doesn't come with headers, so you'll need to solder some on.  Takes about 5 minutes.  
$1.50 from Sparkfun (http://www.sparkfun.com/products/10007) or adafruit (https://www.adafruit.com/products/85)


code stuff:
all you have to do to configure this code is to set the wireless internet ssid and password (if it's an open network, just use '0' 
for the password).  Give the printer a unique name, and upload that sketch!
The printer itself has five wires coming out:  power, ground, serial TX, serial RX, and another ground.
Connect the ground to the arduino ground, you'll need a beefy 5-9V supply to power the printer, and connect the RX (the green) wire
to pin 2 of the arduino and the TX (yellow) wire to pin 3.  You should be good to go.

The printer can search for and print out any topic you like on twitter.  To set the topic for your printer, go to 
artiswrong.com/oceanPrinter/
Type in your printer name and the topic.  If you want to change the topic, just type in whatever you want and resubmit the form.  The
printer automatically checks the website before searching twitter, so your updates should be instantaneous.


The arduino will work by itself, but you can listen to it over the serial connection at 115200 baud and hear all the chatter going 
back and forth to the various websites.

Libraries:
I use ladyada's AWESOME thermal printer library (download it here:  https://github.com/adafruit/Adafruit-Thermal-Printer-Library)
and the alpha 1 release of Sparkfun's Wifly library (download it here:  http://sparkfun.com/Code/wifly/WiFly-20100831-alpha-1.zip)

If you have any questions/suggestions, ping me at alex@manilamantis.com
If you're interested in contributing to the code, holler at me and I'll add you to the project.  Contributors are WELCOME!

IMPORTANT---this code will NOT compile on arduino 1.0.  The wifly library isn't
arduino 1.0 compatible.  I developed and tested on arduino 0022, and it works just
fine.  Save yourself a world o hurt and grab arduino 0022 from http://arduino.cc/en/Main/Software


************************************************************/

#include "WiFly.h"
// if you're using Arduino 23 or earlier, uncomment the next line
#include "NewSoftSerial.h"
#include "Adafruit_Thermal.h"

#include "Credentials.h"

#define HEADER 0
#define BODY 1
#define JSON 1
#define FROM_USER 2
#define MESSAGE 3

#define PARSE_KEY 0 
#define KEY 1
#define END_KEY 2
#define PARSE_VALUE 3
#define VALUE 4
#define END_VALUE 5


int printer_RX_Pin = 2;  // this is the green wire
int printer_TX_Pin = 3;  // this is the yellow wire

Adafruit_Thermal printer(printer_RX_Pin, printer_TX_Pin);


char trigger=PARSE_KEY;

unsigned char parenCount=0;

boolean parsing;
boolean mode=HEADER;

boolean topicMode=HEADER;

String tweet="";
String username="";
String date="";
String id="";
String lastID="";
String topic="";
String lastTopic="";
String baseRequest="GET /search.json?rpp=1";

String request;

String key;
String value;
unsigned char index;

String formattedTweet[6];

byte twitter[] = { 199, 59, 148, 201}; //search.twitter.com

byte artiswrongServer[] = {97, 107, 134, 162 };

Client client(twitter, 80);

Client artiswrong(artiswrongServer, 80);

void setup() {
  
  Serial.begin(115200);
  printer.begin();
  printer.upsideDownOn(); //prints upside-down so the string of paper can hang down from the ceiling
  WiFly.begin();
  
  if (!WiFly.join(ssid, passphrase)) {
    Serial.println("Association failed.");
    while (1) {
      // Hang on failure.
    }
  }  

  
}

void grabTopic()
{
    Serial.println("connecting to artiswrong...");

  if (artiswrong.connect()) {
    Serial.println("connected");
    String request="Get /oceanPrinter/topic.php?printerName=";  
  
    #ifdef DEBUG
      Serial.print("my printer name:  ");
      Serial.println(printerName);
    #endif
    
    request+=printerName;
    request+=" HTTP/1.0";

    #ifdef DEBUG
      Serial.print("topic request: ");
      Serial.println(request);
    #endif

    artiswrong.println(request);
    artiswrong.println();
    parsing=true;  //we're ready to parse
  } else {
    Serial.println("connection failed");
  }
}

void parseTopic()
{
  topicMode=HEADER;
  topic="";
  while(parsing){
  if (artiswrong.available()) {
    char c = artiswrong.read();
    Serial.print(c);
    if(topicMode==BODY)
        topic+=c;
    if(c=='#')
      topicMode=BODY;
   
  }
  
  if (!artiswrong.connected()) {
    Serial.println();
    Serial.println("disconnecting.");
    artiswrong.stop();
    parsing=false;
    if(topic.compareTo(lastTopic)!=0)  //if we've got a new topic, we should reset the latest tweet id
      lastID="";
    lastTopic=topic;
  }
}  
}

  
void grabTweet()
{
  tweet="";
  username="";
  date="";
  
  Serial.println("connecting to twitter...");

  if (client.connect()) {
    Serial.println("connected");
    
    #ifdef DEBUG
      Serial.print("base request :");
      Serial.println(baseRequest);
      Serial.print("topic: ");
      Serial.println(topic);
    
    #endif
    
    request=baseRequest;
    request+="&q=";
    request+=topic;
    
    #ifdef DEBUG
    
      Serial.print("request so far: ");
      Serial.println(request);
    
    #endif
    
     if(lastID.compareTo("")!=0)
     {
       request+="&since_id=";
       request+=lastID;
     }
    request+=" HTTP/1.0";
    
        Serial.print("http request: ");
    Serial.println(request);
    client.println(request);
    client.println();
    parsing=true;  //we're ready to parse
  } else {
    Serial.println("connection failed");
  }
}

void parseTweet()
{
  while(parsing)
  {
  if (client.available()) {
    char c = client.read();
    if(c=='[')
      mode=JSON;
    if(c==']')
      mode=HEADER;
    if(mode==JSON)
    {
      #ifdef DEBUG
        Serial.print(c);
      #endif

  /*twitter returns a long JSON barf.  It's a long and complicated format, and beyond the scope of a humble comment,
  but the general format is {[
                              "key":"value",
                              "key":"value",
                              "key":"value",
                              ....]}
                                
  The arduino doesn't have enough memory to store the entire twitter response, so we need to parse it on-the-fly.  This is 
  a simple parser that looks for patterns of quotes, colons and commas to determine if the incoming text is a key or value string.
  It stores the incoming characters, character-by-character, by appending them to either a 'key' or 'value' temporary string.  Once 
  it has both a key and a value, the parser checks the key against the four keys we're interested in:
  "created_at" : the tweet timestamp
  "from_user" :  the username of the person who sent the tweet
  "text"  :  the tweet
  "id_str" :  the unique ID of the tweet--we use it to keep from printing out duplicate duplicate tweets
  
  If the key matches, the code stores the 'value' string into either a 'tweet', 'username', 'id' or 'date' string.  If there's no
  match, it does nothing with the data, and it'll be overwritten next time around the loop.  I can't help but feel bad for all those
  useless dictionary entries.  *sniff* goodbye, 'geo'.  goodbye, 'source'  
  */
  
      switch(trigger){
         case(PARSE_KEY):
          if(c=='\"')
          {
           key="";
           value="";
           trigger=KEY;
           #ifdef DEBUG
             Serial.println(" key");
           #endif
           index=0;
           }
         break;
         
         case(KEY):
          if(c=='\"')
          {
           trigger=END_KEY;
           #ifdef DEBUG
             Serial.println(" end key");
           #endif
           }
           else
             key+=c;
           break;
       
         case(END_KEY):
          if(c==':')
          {
            trigger=PARSE_VALUE;
           #ifdef DEBUG
            Serial.println(" parse value");
           #endif
          }
          break;
                            
        case(PARSE_VALUE):
        if(c=='\"')
        {
          trigger=VALUE;
           #ifdef DEBUG
            Serial.println(" value");
           #endif
        }
        break;
      case(VALUE):
        if(c=='\"')
        {
          trigger=PARSE_KEY;
           #ifdef DEBUG
            Serial.println(" end value");
           #endif
          Serial.print(key);
          Serial.print(" : ");
          Serial.print(value);
          Serial.println();
          if(key.compareTo("created_at")==0)
              date=value;
          if(key.compareTo("from_user")==0)
              username=value;
          if(key.compareTo("text")==0)
              tweet=value;
          if(key.compareTo("id_str")==0)
              id=value;
           
            
          
        }
        else
          value+=c;
        break;  
      }
    }
  }
  
  if (!client.connected()) {
    Serial.println();
    Serial.println("disconnecting.");
    client.stop();
    Serial.print(username);
    Serial.println(" says: ");
    Serial.print(tweet);
    Serial.println();
    Serial.println(date);
    Serial.print("ID: ");
    Serial.println(id);
    lastID=id;
    parsing=false;
  }
  }
}

void prettyFormatting()
{
  
}

void printTweet()
{
    if(tweet.compareTo("")!=0)  //make sure we got a tweet
    {

            printer.inverseOn();
            printer.print("@"+username);
            printer.inverseOff();
            printer.println(" says:");
            printer.println(tweet);
            printer.println(date);
            printer.feed(2);
    }
    else
      Serial.println("nothing yet...");
   
}


void loop() {
  grabTopic();
  parseTopic();
  grabTweet();
  parseTweet();
  printTweet();
}


