import javax.sound.midi.*;
import javax.sound.sampled.*;
import java.io.*;
import java.util.*;
import processing.sound.*;


Sequencer sequencer;
Receiver recv;
Transmitter mitter;
TargetDataLine line = null;
byte[] audio = new byte[10000000];
OutputStream audioRecord;
AudioFileFormat.Type fileType = AudioFileFormat.Type.WAVE;
AudioFormat format;
ByteArrayInputStream inputStream;
AudioInputStream audioInputStream;
int count = 0;
MidiDevice.Info myMidiOut;

void setup() {
  size(640, 360);

showMixers();


 audioRecord =  createOutput("./midifiles/recording.wav");

  Mixer.Info[] mixers = AudioSystem.getMixerInfo();
  
  Mixer recordingMixer = AudioSystem.getMixer(mixers[18]);
  //Mixer: 19UFX1604 Input 13/14 (Behringer , supports TargetDataLine , Direct Audio Device: DirectSound Capture
  
  /*
  To record in Windows 11, you have to select the mixer for the default sound input for recording.
  Also has to be allowed, naturally, to be default in first place. Just showing up in the list of inputs
  is NOT good enough.
  If you can't find a device in the sound settings, scroll down to All Sound Devices and you may find it was disabled.
  */
  
  println("using mixer " + recordingMixer.getMixerInfo().toString());
  
  Line[] lines =  recordingMixer.getSourceLines();
  println("** lines = " + lines.length);
  for (int i = 0; i < lines.length; i++) {
    println (lines[i].getLineInfo().toString());
  }
   
    try {
   // Set the audio format

   format = new AudioFormat(44000.0, 16, 2, true, false);
   inputStream = new ByteArrayInputStream(audio);
            audioInputStream = new AudioInputStream(inputStream, format, audio.length / format.getFrameSize());
   
   // Get the default microphone as the target data line for recording
   DataLine.Info info = new DataLine.Info(TargetDataLine.class, format);
   line = (TargetDataLine) AudioSystem.getLine(info);
   
   // Open the target data line for recording
   line.open(format, 8192);
   
   // Start recording
   line.start();
   }
   catch (LineUnavailableException e) {
   e.printStackTrace();
   }
   
  
  
  try {

    // Get a Sequencer instance
    sequencer = MidiSystem.getSequencer();
    // Open the sequencer
    sequencer.open();
    // Set the sequence for the sequencer
    Sequence sequence = MidiSystem.getSequence(createInput("./midifiles/midiexport.mid"));
    sequencer.setSequence(sequence);

//examine all events in the sequence
    dumpSequence(sequence);

    //for writing a track as a midi test
    Track track = sequence.getTracks()[0];
    mitter = sequencer.getTransmitter();
    // Start playing the sequence on the specified MIDI output port of the MOTU express
    recv = getReceiver(2);
    //set to transmit on this port to device
    mitter.setReceiver(recv);
    // Loop through the track's MIDI events
    for (int i = 0; i < 2; i++) {
      MidiEvent event = track.get(i);
      int status = event.getMessage().getStatus();
      println("tick = " + event.getTick() + " and status = " + status);
      if ( status >= 144 && status <= 159) {
        println("note on");
        println("note =" + event.getMessage().getMessage()[1]);
        println(event.getTick());
      }
      if (status >= 128 && status <= 143) {
        ;
        println("note off");
        println("note =" + event.getMessage().getMessage()[1]);
        println(event.getTick());
      }
    }

    //shows how to do it
    writeMidiFile();
    //play afile and record the audio
    sequencer.start();
  }
  catch (Exception ex) {
    ex.printStackTrace();
  }
}

void draw() {
  background(255);
  fill(0);
  textSize(20);
  text("Playing MIDI file..." + sequencer.getMicrosecondPosition()/1000, width/2, height/2);

//I am recording????  read(byte[] b, int off, int len)

  count =  count +  line.read(audio, count, line.available());
  //println("read audio = " + count);
  //add bytes to big array
  //println(Arrays.toString(audio));
  
  if (!sequencer.isRunning()) {
    //close and exit
    // Close the sequencer
    sequencer.close();
    line.stop();
    line.close();
    
      try {
  // Write the recorded audio data to the audio file
  InputStream stream = new ByteArrayInputStream (audio, 0, count);
  AudioInputStream audioInputStream = new AudioInputStream(stream, format, count);
  AudioSystem.write(audioInputStream, fileType, audioRecord);
  
  }
  catch (IOException e) {
    e.printStackTrace();
  }
    exit();
  }
}



Receiver getReceiver(int channel) throws MidiUnavailableException {

  Receiver receiver = null;
  MidiDevice.Info[] info = MidiSystem.getMidiDeviceInfo();

  for (int i = 0; i < info.length; i++) {
    println(info[i]);
    //scan for channel number. not great.
    if (info[i].toString().contains("Express  128: Port " + channel))
    {
      //found receiver
      println("**************** found requested device: " + info[i]);
      MidiDevice device = MidiSystem.getMidiDevice(info[i]);
      device.open();
      receiver = device.getReceiver();
      break;
    }
  }
  return receiver;
}

/*

 I can create a track and add midievents to it.
 
 convert track to file??
 
 */
void writeMidiFile() {
  try {
    // Create a new sequence with 96 tick per quarter note and 1 track
    Sequence sequence = new Sequence(Sequence.PPQ, 960, 1);

    // Create a new track
    Track track = sequence.createTrack();

    // Set the tempo of the track to 120 BPM (beats per minute)
    int tempo = 500000; // microseconds per quarter note. OMG. last three bytes are 500,000 in hex bytes
    byte[] data = new byte[]{0x51, 0x03, 0x07, (byte)160, 0x20};

    //byte wtx = 0xa6;

    MidiMessage tempoMsg = new MetaMessage(0x51, data, data.length);
    //0x51 = set tempo. see https://mido.readthedocs.io/en/latest/meta_message_types.html
    MidiEvent tempoEvent = new MidiEvent(tempoMsg, 0);
    //adds event at time tick = 0
    track.add(tempoEvent);

    //here we would add a sequence of on/off data all for the same note. can ignore the pedal for now.

    for (int i = 0; i < 100; i++) {
      // Add a Note On event to the track for C4 (MIDI note number 60) with velocity 64 at tick 0
      ShortMessage noteOn = new ShortMessage();
      noteOn.setMessage(ShortMessage.NOTE_ON, 0, 60 + i % 24, 64);
      MidiEvent noteOnEvent = new MidiEvent(noteOn, i * 960);
      track.add(noteOnEvent);

      // Add a Note Off event to the track for the same note with velocity 0 at tick 96 (equivalent to a quarter note)
      ShortMessage noteOff = new ShortMessage();
      noteOff.setMessage(ShortMessage.NOTE_OFF, 0, 60  + i % 24, 0);
      MidiEvent noteOffEvent = new MidiEvent(noteOff, i * 960 + 960);
      track.add(noteOffEvent);
    }

    println("track event count = " + track.size());
    println("track ticks = " + track.ticks());


    //write the data to the console as a check.
    MidiSystem.write(sequence, 1, System.out);

    OutputStream stream =  createOutput("./midifiles/output.mid");
    // Write the sequence to a MIDI file named "output.mid". type 0 is not allowed. Using type 1.
    MidiSystem.write(sequence, 1, stream);
    stream.close();
  }
  catch (Exception ex) {
    ex.printStackTrace();
  }
}




void showMixers() {
  ArrayList<Mixer.Info>
    mixInfos =
    new ArrayList<Mixer.Info>(
    Arrays.asList(
    AudioSystem.getMixerInfo(
    )));
  Line.Info sourceDLInfo =
    new Line.Info(
    SourceDataLine.class);
  Line.Info targetDLInfo =
    new Line.Info(
    TargetDataLine.class);
  Line.Info clipInfo =
    new Line.Info(Clip.class);
  Line.Info portInfo =
    new Line.Info(Port.class);
  String support;
  int index = 0;
  for (Mixer.Info mixInfo :
    mixInfos) {
    Mixer mixer =
      AudioSystem.getMixer(
      mixInfo);
    support = ", supports ";
    if (mixer.isLineSupported(
      sourceDLInfo))
      support +=
        "SourceDataLine ";
    if (mixer.isLineSupported(
      clipInfo))
      support += "Clip ";
    if (mixer.isLineSupported(
      targetDLInfo))
      support +=
        "TargetDataLine ";
    if (mixer.isLineSupported(
      portInfo))
      support += "Port ";
    System.out.println("Mixer: " + index 
      + mixInfo.getName() +
      support + ", " +
      mixInfo.getDescription(
      ));
      
      index++;
  }
}



void dumpSequence(Sequence seq) {
  
  //first track just had special commands. track 1 contains the actual data. SMF Type 1.
  /*
  144 = note on
  128 = note off
  176 = chan1 control/mode change. 64 = sustain pedal.
  
  negative byte values just need 256 added to them.
  
  */
  Track track = seq.getTracks()[1];
  MidiEvent event = null;
  long tick = 0;
  for (int i = 0; i < track.size(); i++)
  {
      event = track.get(i);
      print("status = " + event.getMessage().getStatus() + "  ");
      byte[] msg = event.getMessage().getMessage();
      for (int j = 0; j < msg.length; j++) {
         print(" byte " + j + "= " + msg[j]); 
      }
      tick = event.getTick();
      println(" tick= " + tick);
      
  }
  
  
  
  
  
}
