#include <EEPROM.h>

/************************************************************
Alex Hornstein
Wireless Twitter Printer
5.6.12
an Ocean Invention project


with mighty thanks to the work of Sparkfun and Adafruit

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


