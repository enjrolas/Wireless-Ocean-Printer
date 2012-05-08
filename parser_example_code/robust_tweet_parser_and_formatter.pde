#include <EEPROM.h>
#include <avr/pgmspace.h>

#define PARSE_KEY 0 
#define KEY 1
#define END_KEY 2
#define PARSE_VALUE 3
#define VALUE 4
#define NESTED_VALUE 5

String username, id, text, key, value, date;

char tweet[]="{\"created_at\":\"Tue, 08 May 2012 00:31:18 +0000\",\"from_user\":\"_MarcDogg\",\"from_user_id\":287490348,\"from_user_id_str\":\"287490348\",\"from_user_name\":\"Marcus Johnson\",\"geo\":null,\"id\":199657693198290944,\"id_str\":\"199657693198290944\",\"iso_language_code\":\"en\",\"metadata\":{\"result_type\":\"recent\"},\"profile_image_url\":\"http://a0.twimg.com/profile_images/2193451258/3c747mubxmbg6e7o3nu7_normal.jpeg\",\"profile_image_url_https\":\"https://si0.twimg.com/profile_images/2193451258/3c747mubxmbg6e7o3nu7_normal.jpeg\",\"source\":\"&lt;a href=&quot;http://twicca.r246.jp/&quot; rel=&quot;nofollow&quot;&gt;twicca&lt;/a&gt;\",\"text\":\"RT @iTweetYourDay: #ilaughalotwhen I know i shouldn't.\",\"to_user\":null,\"to_user_id\":null,\"to_user_id_str\":null,\"to_user_name\":null}]";

char trigger=PARSE_KEY;

void setup()
{
  Serial.begin(115200);
  parseTweet();
    Serial.print(username);
    Serial.println(" says: ");
    Serial.print(text);
    Serial.println();
    Serial.println(date);
    Serial.print("ID: ");
    Serial.println(id);
  
}


void parseTweet()
{
  int i=0;
  boolean finished=false;
  while((i<strlen(tweet))&&(finished==false))
  {
    
    char c =tweet[i];
   // Serial.print(c);
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
           }
          if(c==']')  //we've reached the end of the json-y goodness
            finished=true;
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
            trigger=PARSE_VALUE;  //start looking for a character to signify the start of a value string
           #ifdef DEBUG
            Serial.println(" parse value");
           #endif
          }
          break;
                            

        //value strings will either start with a double quote, a left curly brace, or the text 'null' in the case of a null value.  I only
        //want values that are plaintext within quotes, so I'm going to chuck everything else        
        case(PARSE_VALUE):
        if(c==',')  //null value, often seen in geo
        {
          trigger=PARSE_KEY;
          value="";
        }
        if(c=='{') //it's a nested value, let's chuck it
          trigger=NESTED_VALUE;
        if(c=='\"')
        {
          trigger=VALUE;
           #ifdef DEBUG
            Serial.println(" value");
           #endif
        }
        break;
        
      case(NESTED_VALUE):
        if(c=='}')   //we've reached the end of our nest, thank god.  Throw out the value and move on to the next entry
          trigger=PARSE_KEY;
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
              text=value;
          if(key.compareTo("id_str")==0)
              id=value;
          }
          else 
            value+=c;
        break;
      }
      i++;
  }
  
}

void prettyFormatting()
{
  
}



void loop() {

}


