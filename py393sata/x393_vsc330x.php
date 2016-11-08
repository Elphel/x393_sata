<?php
/*!*******************************************************************************
*! FILE NAME  : x393_vsc330x.php
*! DESCRIPTION: web interface for VSC3304 crosspoint switch in 393 camera
*! Copyright (C) 2012 - 2016 Elphel, Inc
*! -----------------------------------------------------------------------------**
*!
*!  This program is free software: you can redistribute it and/or modify
*!  it under the terms of the GNU General Public License as published by
*!  the Free Software Foundation, either version 3 of the License, or
*!  (at your option) any later version.
*!
*!  This program is distributed in the hope that it will be useful,
*!  but WITHOUT ANY WARRANTY; without even the implied warranty of
*!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*!  GNU General Public License for more details.
*!
*!  You should have received a copy of the GNU General Public License
*!  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*! -----------------------------------------------------------------------------**
*/
// require 'i2c.inc';
// include 'show_source.inc';

$debug=false;
$BUS=1; // 1 - 10369, 0 - 10359 (sensor)
$slaveAddrVCS3312=     0x2d;

$i2c_Page_Connection=      0x00; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding output (0..0xf) source (input number)
                                 // bit 4 (+0x10) - turn output off, bits 3:0 - source
$i2c_Page_InputISE=        0x10; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding input (0..0xf) ISE (equalization):
                                 // Bits 5:4 ISE short: 0 - off, 1 - minimal, 2 - moderate, 3 - maximal; bits 3:2 ISE medium, bits 1:0 ISE Long time constant
$i2c_Page_InputState=      0x11; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding input (0..0xf) enable, polarity and termination (default 6)
                                 // Bit 2 (+4) Terminate to VDD ( 0 - connect,  1 - do not connect) - dedicated (0..7) inputs only
                                 // Bit 1 (+2) Input power (0 - on, 1 - off)
                                 // Bit 0 (+1) Invert signal at input 
///$i2c_InputStateData=       0x04; // terminated,enabled, not inverted
$i2c_InputStateData=       0x00; // terminated,disabled, not inverted
$i2c_Page_InputLOS=        0x12; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding input (0..0xf) LOS (loss of signal) threshold
                                 // Bits 2:0 - level in mV for dedicated(bidirectional) inputs: 0,1,6,7 - unused, 2 - 150(170), 3 - 200(230), 4 - 250(280), 5 - 300(330)
$i2c_Page_OutputPreLong=   0x20; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding output (0..0xf) long time constant pre-emphasis
                                 // Bits 6:3 Pre-Emphasis level (0x0 - off, 0x1 - min, 0xf - max - 0..6dB), bits 2:0 - Pre-emphasis decay (0x0 - fastest, 0x7 - slowest) in 500..1500 ps range
$i2c_Page_OutputPreShort=  0x21; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding output (0..0xf) short time constant pre-emphasis
                                 // Bits 6:3 Pre-Emphasis level (0x0 - off, 0x1 - min, 0xf - max - 0..6dB), bits 2:0 - Pre-emphasis decay (0x0 - fastest, 0x7 - slowest) in 30..500 ps range
$i2c_Page_OutputLevel=     0x22; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding output (0..0xf) short time constant pre-emphasis
                                 // Bits 3:0 - peak-to-peak 0,1,0xe,0xf - unused, 0x2-405mV,0x3-425V,0x4-455mV,0x5-485mV,0x6-520mV,0x7-555mV,0x8-605mV,0x9-655mV,0xa-720mV,0xb-790mV,0xc-890mV,0xd-990mV (+3.3VDC required)
                                 // bit 4 (+0x10) - for 8-15 used as inputs only: terminate inputs 8..15 to VDDIO-0.7V
$i2c_Page_OutputState=     0x23; // When written to $i2c_CurrentPage, makes registers 0..0xf control corresponding output (0..0xf) OOB signaling and output polarity
                                 // bits 4:1 - operation mode: 0xa  - inverted, 0x5 - normal, 0x0 - suppressed
                                 // bit 0 - OOB control:     1 - enable LOS forwarding, 0 - ignore LOS
$i2c_Page_ChannelStatus=   0xf0; // When written to $i2c_CurrentPage, makes registers 0..0xf monitor corresponding input (0..0xf) LOS status
                                 // bit 0 - LOS status: 1 - LOS detected (loss of signal), 0 - signal present (input has to be enabled, otherwise 0 is read)
                                 // when reading from address 0x10 of this page:
                                 //  bit 0 - value of STAT0
                                 //  bit 1 - value of STAT1
$i2c_Page_Status0Configure=0x80; // When written to $i2c_CurrentPage, makes registers 0..0xf control selected input LOS to be OR-ed to STAT0 output pin (and bit)
                                 // bit 0 : 1 - OR this input channel LOS status to STAT0
$i2c_Page_Status1Configure=0x81; // When written to $i2c_CurrentPage, makes registers 0..0xf control selected input LOS to be OR-ed to STAT1 output pin (and bit)
                                 // bit 0 : 1 - OR this input channel LOS status to STAT1

$i2c_GlobalConnection=     0x50; // Bit 4 (+0x10) - disable all outputs, bits 3:0 - input number to connect to all outputs
$i2c_GlobalInputISE=       0x51; // Bits 5:4 ISE short: 0 - off, 1 - minimal, 2 - moderate, 3 - maximal; bits 3:2 ISE medium, bits 1:0 ISE Long time constant
$i2c_GlobalInputState=     0x52; // Bit 2 (+4) - terminate input to VDD (0..7 only) 0-connect, 1 Normal; Bit 1 (+2) Input power off (0 - On, 1 - Off) bit0 (+1): Input polarity: 1 - inverted, 0 - normal 
$i2c_GlobalInputLOS=       0x53; // Bits 2:0 - level in mV for dedicated(bidirectional) inputs: 0,1,6,7 - unused, 2 - 150(170), 3 - 200(230), 4 - 250(280), 5 - 300(330)
$i2c_GlobalOutputPreLong=  0x54; // Bits 6:3 Pre-Emphasis level (0x0 - off, 0x1 - min, 0xf - max - 0..6dB), bits 2:0 - Pre-emphasis decay (0x0 - fastest, 0x7 - slowest) in 500..1500 ps range
$i2c_GlobalOutputPreShort= 0x55; // Bits 6:3 Pre-Emphasis level (0x0 - off, 0x1 - min, 0xf - max - 0..6dB), bits 2:0 - Pre-emphasis decay (0x0 - fastest, 0x7 - slowest) in 30..500 ps range
$i2c_GlobalOutputLevel=    0x56; // Bits 3:0 - peak-to-peak 0,1,0xe,0xf - unused, 0x2-405mV,0x3-425V,0x4-455mV,0x5-485mV,0x6-520mV,0x7-555mV,0x8-605mV,0x9-655mV,0xa-720mV,0xb-790mV,0xc-890mV,0xd-990mV (+3.3VDC required)
                                 // bit 4 (+0x10) terminate inputs 8..15 to VDDIO-0.7V
$i2c_GlobalOutputState=    0x57; // +1 (bit 0) - LOS, +0x15 - inverted, 0xa0 - normal, +0 - "Common mode" ?
$i2c_GlobalOutputStateData=0x0b; // No inversion, enable OOB forwarding on all channels
$i2c_Status0=              0x58; // Bit 0 - selected for Status0 chanel LOS on
$i2c_Status1=              0x59; // Bit 0 - selected for Status1 chanel LOS on // Which channel LOS to show on Status1 output/bit
$i2c_CoreConfiguration=    0x75;
$i2c_CoreConfigurationData= 0x18; // default 0x18 - 0x10 - leftEn, 0x8 - rightEn, 0x4 - DNU, 0x2 - BufferForceOn, 0x1 - Config polarity
$i2c_CoreConfigurationDataF=0x19; // default with inverted Config polarity (freeze update)
$i2c_SlaveAddress=         0x78; // programmed only, not hardwired
$i2c_InterfaceMode=        0x79;
$i2c_InterfaceModeData=    0x02; // i2c (1 - 4-wire)
$i2c_SoftwareReset=        0x7a;
$i2c_SoftwareResetData=    0x10; // to reset, 0 - normal
$i2c_CurrentPage=          0x7f;

$vsc_sysfs_dir = '/sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0/0-0001';

$connections=array(); // pairs, first index< second
// $channels=array(
//                   array('in'=>10,  'out'=> 3, 'name'=>'host1', 'connector'=> 1),
//                   array('in'=> 3,  'out'=>10, 'name'=>'host2', 'connector'=> 2),
//                   array('in'=> 0,  'out'=> 5, 'name'=>'host3', 'connector'=> 3),
//                   array('in'=> 4,  'out'=> 4, 'name'=>'host4', 'connector'=> 4),
//                   array('in'=> 9,  'out'=> 0, 'name'=>'host5', 'connector'=> 5),
//                   array('in'=> 7,  'out'=> 9, 'name'=>'host6', 'connector'=> 6),
//                   array('in'=>11,  'out'=> 1, 'name'=>'ssd1',  'connector'=> 7),
//                   array('in'=> 8,  'out'=> 6, 'name'=>'ssd2',  'connector'=> 8),
//                   array('in'=> 5,  'out'=>11, 'name'=>'ssd3',  'connector'=> 9),
//                   array('in'=> 2,  'out'=> 2, 'name'=>'ssd4',  'connector'=>10),
//                   array('in'=> 1,  'out'=> 8, 'name'=>'ssd5',  'connector'=>11));
$channels=array(
		array('in'=> 12, 'out'=> 8,  'name'=>'A', 'connector'=> 1),
        array('in'=> 13, 'out'=> 9,  'name'=>'B', 'connector'=> 2),
        array('in'=> 14, 'out'=> 10, 'name'=>'C', 'connector'=> 3),
        array('in'=> 15, 'out'=> 11, 'name'=>'D', 'connector'=> 4),
        array('in'=> 8,  'out'=> 12, 'name'=>'E', 'connector'=> 5),
        array('in'=> 9,  'out'=> 13, 'name'=>'F', 'connector'=> 6),
        array('in'=> 10, 'out'=> 14, 'name'=>'G', 'connector'=> 7),
        array('in'=> 11, 'out'=> 15, 'name'=>'H', 'connector'=> 8));

/** Paths to parameters in sysfs */
$param_paths = array(
		'input_ISE_short'        => $vsc_sysfs_dir . '/input_ISE_short/',
		'input_ISE_medium'       => $vsc_sysfs_dir . '/input_ISE_medium/',
		'input_ISE_long'         => $vsc_sysfs_dir . '/input_ISE_long/',
		'input_terminate'        => $vsc_sysfs_dir . '/input_terminate_high/',
		'input_invert'           => $vsc_sysfs_dir . '/input_state_invert/',
		'input_LOS'              => $vsc_sysfs_dir . '/input_LOS_threshold/',
		'input_off'              => $vsc_sysfs_dir . '/input_state_off/',
		
		'output_PRE_long_decay'  => $vsc_sysfs_dir . '/output_PRE_long_decay/',
		'output_PRE_long_level'  => $vsc_sysfs_dir . '/output_PRE_long_level/',
		'output_PRE_short_decay' => $vsc_sysfs_dir . '/output_PRE_short_decay/',
		'output_PRE_short_level' => $vsc_sysfs_dir . '/output_PRE_short_level/',
		'output_level'           => $vsc_sysfs_dir . '/output_level/',
		'output_mode'            => $vsc_sysfs_dir . '/output_mode/',
		'forward_OOB'            => $vsc_sysfs_dir . '/forward_OOB/',
		'status'                 => $vsc_sysfs_dir . '/status/',
		'connections'            => $vsc_sysfs_dir . '/connections/'
);
$numHosts=6;
if (count($_GET)==0){
  showUsage();
  exit (0);
}

$debug= isset($_GET['debug']);
$init= !isset($_GET['noinit']); // default - on
$dry=   isset($_GET['dry']); // dry run, no actual programming over i2c
$error=false;
$port_ise =        array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_input_state= array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_los=         array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_pre_long=    array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_pre_short=   array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_out_level=   array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_out_state=   array(); //-1=>'','','','','','','','','','','','',''); // -1(all),0..11
$port_channel_status=array(); // read only - 1 - LOS
$port_channel_input=  array(); // read current connections (number of input or "-1" - disabled
if ($init) {
  $port_ise[-1]=         array('short'=>0,'medium'=>0,'long'=>0);
//  $port_input_state[-1]= array('terminate'=>1,'invert'=>0); // change to no termination?
  $port_input_state[-1]= array('terminate'=>0,'invert'=>0); // change to no termination?
  $port_los[-1]=         array('level'=>4); // 250 mv
  $port_pre_long[-1]=    array('level'=>0,'decay'=>0);
  $port_pre_short[-1]=   array('level'=>0,'decay'=>0);
  $port_out_level[-1]=   array('level'=>6);
  $port_out_state[-1]=   array('mode'=>5,'oob'=>1);
}
$SA=$slaveAddrVCS3312<<8;


foreach ($_GET as $cmdkey=>$value) {
  if (strpos($key,":" )>=0){
    $command=strtok($cmdkey,":");
    $key=    strtok(":");
  } else {
    $command="";
    $key=$cmdkey;
  }
  $port=  parsePort($key);
  $inPort=   parseInPort($key);
  $outPort=  parseOutPort($key);
  if ($debug) {
    echo "<!--$command:$key=$value -->\n";
  }
  
  switch (strtoupper($command)) {
//    case '':
    case 'S':
    case 'STATE':
  echo <<<EOT
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <title>SATA Multiplexer Current State</title>
</head>
<body>
EOT;
         readCurrentState(); // outputs comments, so <head> should be before it
         showCurrentStateHTML();
         echo "</body>\n";
         exit(0); 
    case 'CONNECTION':
    case 'CON':
    case 'C':
       $pair=array($port,parsePort($value));
       sort($pair);
//       print_r($pair);
       if (($pair[0]>=0) &&
           ($pair[0]<$numHosts) &&
           ($pair[1]>=$numHosts) &&
           ($pair[1]<count($channels))) {
// remove duplicate IO-s
           $duplicateIO=false;
           foreach ($connections as $connection) if (($connection[0]==$pair[0]) || ($connection[1]==$pair[1])){
              $duplicateIO=true;
              break;
           }
          if (!$duplicateIO) $connections[count($connections)]=$pair;
          else {
            echo "Duplicate connection for ".$key.": \n";
            print_r($pair);
            echo "Current connections:\n";
            print_r($connections);
          }
       }
       break;
    case 'ISE':
      $aval=getMultiVals($value);
      if (count($aval)!=3) {
        echo "Value for the ISE (input signal equalization) command is expected to be short_value:medium_value:long_value, got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_ise=array('short'=>$aval[0],'medium'=>$aval[1],'long'=>$aval[2]);
      if (($inPort>=-1) && ($port<12)) $port_ise[$inPort]=$this_ise;
      else {
        echo "Invalid input port index=$inPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
    case 'IN_STATE':
      $aval=getMultiVals($value);
      if (count($aval)!=2) {
        echo "Value for the IN_STATE (input state) command is expected to be terminate_to_VCC:invert, got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_input_state=array('terminate'=>$aval[0],'invert'=>$aval[1]);
      if (($inPort>=-1) && ($port<12)) $port_input_state[$inPort]=$this_input_state;
      else {
        echo "Invalid input port index=$inPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
    case 'LOS':
      $aval=getMultiVals($value);
      if ((count($aval)!=1) || ($aval[0]<0)  || ($aval[0]>7)) {
        echo "Value for the LOS (loss of signal) command is expected to be a 0..7 integer, got >$value<\n";
        $error =true;
        exit (1);
      }
      if (($inPort>=-1) && ($inPort<12)) $port_los[$inPort]=array('level'=>$aval[0]);
      else {
        echo "Invalid input port index=$inPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;

    case 'PRE_LONG':
      $aval=getMultiVals($value);
      if (count($aval)!=2) {
        echo "Value for the PE_LONG (output pre-emphasis long time constant) command is expected to be pre_emphasis_level[0..15]:pre_emphasis_decay[0..7], got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_pre_long=array('level'=>$aval[0],'decay'=>$aval[1]);
      if (($outPort>=-1) && ($outPort<12)) $port_pre_long[$outPort]=$this_pre_long;
      else {
        echo "Invalid output port index=$outPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
    case 'PRE_SHORT':
      $aval=getMultiVals($value);
      if (count($aval)!=2) {
        echo "Value for the PE_SHORT (output pre-emphasis short time constant) command is expected to be pre_emphasis_level[0..15]:pre_emphasis_decay[0..7], got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_pre_short=array('level'=>$aval[0],'decay'=>$aval[1]);
      if (($outPort>=-1) && ($outPort<12)) $port_pre_short[$outPort]=$this_pre_short;
      else {
        echo "Invalid output port index=$outPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
//$port_out_level=   array(-1=>array('level'=>6),        '','','','','','','','','','','',''); // -1(all),0..11
    case 'OUT_LEVEL':
      $aval=getMultiVals($value);
      if ((count($aval)!=1) || ($aval[0]<0) || ($aval[0]>15)) {
        echo "Value for the OUT_LEVEL (output signal level) command is expected to be  0..15 value, got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_out_level=array('level'=>$aval[0]);
      if (($outPort>=-1) && ($outPort<12)) $port_out_level[$outPort]=$this_out_level;
      else {
        echo "Invalid output port index=$outPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
//$port_out_state=   array(-1=>array('mode'=>5,'oob'=>1),'','','','','','','','','','','',''); // -1(all),0..11
    case 'OUT_STATE':
      $aval=getMultiVals($value);
      if (count($aval)!=2) {
        echo "Value for the OUT_STATE (output state) command is expected to be mode(10-inverted,5-normal,0-common mode):oob_forwarding, got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_out_state=array('mode'=>$aval[0],'oob'=>$aval[1]);
      if (($outPort>=-1) && ($outPort<12)) $port_out_state[$outPort]=$this_out_state;
      else {
        echo "Invalid output port index=$outPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;


/*

*/
//$port_input_state

  }
}
//print_r($connections);
//echo "</pre>\n";
if (isset($_GET['list']))listSettings();
$activeOutputs=array(false,false,false,false, false,false,false,false, false,false,false,false);
$activeInputs= array(false,false,false,false, false,false,false,false, false,false,false,false);

foreach ($connections as $connection){
  $activeOutputs[$channels[$connection[0]]['out']]=true;
  $activeOutputs[$channels[$connection[1]]['out']]=true;
  $activeInputs [$channels[$connection[0]]['in']]= true;
  $activeInputs [$channels[$connection[1]]['in']]= true;
}
if ($debug) {
  echo "<!-- activeOutputs:\n";
  print_r($activeOutputs);
  echo "\nactiveInputs:\n";
  print_r($activeInputs);
  echo "\nISE (input signal equalization):\n";
  print_r($port_ise);

  echo "\nInput state:\n";
  print_r($port_input_state);
  echo "\nLOS (loss of signal thershold):\n";
  print_r($port_los);

  echo "\nPre-emphasis long:\n";
  print_r($port_pre_long);
  echo "\nPre-emphasis short:\n";
  print_r($port_pre_short);
  echo "\nOutput level:\n";
  print_r($port_out_level);
  echo "\nOutput state:\n";
  print_r($port_out_state);
  echo "-->\n";
}

//exit (0);




    $outputLevel=6; // 520mV
    if ($debug) echo '<!-- setting i2c mode (writing 0x'.dechex($i2c_InterfaceModeData).' to 0x'.dechex($SA | $i2c_InterfaceMode).' -->'."\n";
    i2c_send_or_die($i2c_InterfaceMode,$i2c_InterfaceModeData); // set i2c mode
    // turn off immediate configuration:
    if ($debug) echo '<!-- freezing updates (writing 0x'.dechex($i2c_CoreConfigurationDataF).' to 0x'.dechex($SA | $i2c_CoreConfiguration).' -->'."\n";
    i2c_send_or_die($i2c_CoreConfiguration,$i2c_CoreConfigurationDataF); // freeze updates

    // program ISE
    if ($debug) echo "<!-- program ISE -->\n";
    if (isGlobalSet($port_ise)){
      i2c_send_or_die( $i2c_GlobalInputISE,data_ise(-1));
    }
    if (isIndividualSet($port_ise)) {
      i2c_send_or_die($i2c_CurrentPage,$i2c_Page_InputISE);
       for($index=0;$index<12;$index++) if (isset($port_ise[$index])){
         i2c_send_or_die($index,data_ise($index));
       }
    }

    // program InputState (program termination for inputs 8-11 during programming output
    if ($debug) echo "<!-- program InputState -->\n";
    $dflt_is=0;
    if (isGlobalSet($port_input_state)){
      $dflt_is=data_input_state(-1); // default may be specified even w/o init - it will apply to polarity and termination,
                                     // for inputs that will be programmed anyway, not cause write to global register.
///      if ($init) i2c_send_or_die( $i2c_GlobalInputState,$dflt_is); // will disable all ports - resets current connection
    }
    // here we have to scan all inputs, disable/enable only in $init mode
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_InputState); // select page 0x11  ($i2c_Page_InputState)
    $shared_input_termination=array();
    for ($index=0;$index<12;$index++) {
      $powerOn=$activeInputs[$index] || isset($port_input_state[$index]); // programming input implies it is on
      $data=$dflt_is;
      if (isset($port_input_state[$index])) $data=data_input_state($index);
      $data&=5; // removing poweroff
      if (!$powerOn) $data |=2; 
//      if (isGlobalSet($port_input_state) || $powerOn){
      if ($init || $powerOn){
         i2c_send_or_die($index, $data);  // do not turn off in non-init mode
         if ($index>=8) $shared_input_termination[$index]=(($data&4)==0); // true - terminate
      }
    }


    if ($debug) echo "<!-- program LOS -->\n";
    // program LOS
    if (isGlobalSet($port_los)){
      i2c_send_or_die( $i2c_GlobalInputLOS,data_port_los(-1));
    }
    if (isIndividualSet($port_los)) {
      i2c_send_or_die($i2c_CurrentPage,$i2c_Page_InputLOS);
       for($index=0;$index<12;$index++) if (isset($port_los[$index])){
         i2c_send_or_die($index,data_port_los($index));
       }
    }

    if ($debug) echo "<!-- program pre-emphasis (long) -->\n";
    // program pre-emphasis (long)
    if (isGlobalSet($port_pre_long)){
      i2c_send_or_die( $i2c_GlobalOutputPreLong,data_pre_long(-1));
    }
    if (isIndividualSet($port_pre_long)) {
      i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputPreLong);
       for($index=0;$index<12;$index++) if (isset($port_pre_long[$index])){
         i2c_send_or_die($index,data_pre_long($index));
       }
    }

    if ($debug) echo "<!-- program pre-emphasis (short) -->\n";
//    if ($debug) {echo '<!-- port_pre_short'; print_r($port_pre_short); echo "-->\n";}
    // program pre-emphasis (short)
    if (isGlobalSet($port_pre_short)){
      i2c_send_or_die( $i2c_GlobalOutputPreShort,data_pre_short(-1));
    }
    if (isIndividualSet($port_pre_short)) {
      i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputPreShort);
       for($index=0;$index<12;$index++) if (isset($port_pre_short[$index])){
         i2c_send_or_die($index,data_pre_short($index));
       }
    }


    // program output level and shared inputs (8..11) termination
    if ($debug) echo "<!-- program output level -->\n";
//    if ($debug) {echo '<!-- port_out_level'; print_r($port_out_level); echo "-->\n";}
    if (isGlobalSet($port_out_level)){
      i2c_send_or_die( $i2c_GlobalOutputLevel,data_out_level(-1));
    }
    if (isIndividualSet($port_out_level) ||
               isset($shared_input_termination[ 8]) ||
               isset($shared_input_termination[ 9]) ||
               isset($shared_input_termination[10]) ||
               isset($shared_input_termination[11])) {
      i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputLevel);
       for($index=0;$index<12;$index++) if (isset($port_out_level[$index])){
         i2c_send_or_die($index,data_out_level($index));
       }
       // extra input termination
    if ($debug) echo "<!-- program shared inputs termination -->\n";
       for($index=8;$index<12;$index++) if (isset($shared_input_termination[$index])){
         i2c_send_or_die($index+4,$shared_input_termination[$index]?0x10:0);
       }
    }
    
    if ($debug) echo "<!-- program output state -->\n";
    // program Output State
    if (isGlobalSet($port_out_state)){
      i2c_send_or_die( $i2c_GlobalOutputState,data_out_state(-1));
    }
    if (isIndividualSet($port_out_state)) {
      i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputState);
       for($index=0;$index<12;$index++) if (isset($port_out_state[$index])){
         i2c_send_or_die($index,data_out_state($index));
       }
    }

    if ($debug) echo "<!-- program connections($init) -->\n";
    programConnections($init); // in init mode will disable unused outputs


    if ($debug) echo '<!-- re-enabling updates (writing 0x'.dechex($i2c_CoreConfigurationData).' to 0x'.dechex($SA | $i2c_CoreConfiguration).' -->'."\n";
    i2c_send_or_die( $i2c_CoreConfiguration,$i2c_CoreConfigurationData); // re-enable updates

  exit(0);

function showUsage(){
  $script_name=trim($_SERVER['SCRIPT_NAME'],'/');
  $prefix_url='http://'.$_SERVER['SERVER_ADDR'].$_SERVER['SCRIPT_NAME'];
  echo <<<EOT
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <title>Usage of 103697A SATA multiplexer control interface ($script_name)</title>
</head>

<h2>Usage of $script_name:</h2>
<h3>Commands w/o parameters</h3>
<ul>
 <li><i>list</i> - show settings to be programmed</li>
 <li><i>debug</i> - output all I<sup>2</sup>C commands as HTML comments (visible with "view source")</li>
 <li><i>dry</i> - "dry run" - simulation only, no I<sup>2</sup>C commands are sent to the device</li>
 <li><i>noinit</i> - update only what is specified, do not disable unused i/o</li>
 <li><i>state</i> - show current programmed state of the multiplexer</li>
 <li><i><a href="$prefix_url?source">source</a></i> - show program source code (no other actions)</li>
</ul>
<h3>Commands with parameters</h3>
<p>All commands with parameters have format:</p>
<p><b>command:port=value</b>, where port can be specified in one of the following ways:</p>
<ul>
 <li><i>numeric</i> - 0..11 specify I/O ports as specified for the VSC3312, "-1" means "all" (apply to all ports, lower precedence than specific ports)</li>
 <li><i>J&lt;number&gt;</i> - using connector reference designators as on 103697A circuit diagram (i.e.J3, J10)</li>
 <li><i>host&lt;number&gt;</i> - where number=1..6, with host1...host5 being 10353 (camera) boards and host6 - extrenal eSATA port</li>
 <li><i>ssd&lt;number&gt;</i> - where number=1..5, with ssd1...ssd4 being SSD directly inserted into the 103697A board and ssd5 - optional extra one connected with a cable</li>
 <li><i>global</i> or <i>all</i> - apply to all ports (not valid for "connection" command).</ul>
<br/>
<h4>connection:port1=port2<br/>c:port1=port2</h4>
<p>Connect two ports. The order of the ports is arbitrary, but one has be one of the hosts, and the other - one of the SSD. If <i>noinit</i> does not appear in the url, all unused inputs and outputs will be disabled to reduce power consumption.</p>
<br/>
<h4>ise:port=short_value:medium_value:long_value</h4>
<p>Configure ISE (input signal equalization) levels for short, medium and long time constants. Each value is in the range 0..3 (0- off, 1 - minimal, 2 - moderate, 3 - maximal)</p>
<br/>
<h4>in_state:port=terminate:invert</h4>
<p>Configure input port state. "terminate" (terminate input to VCC) can bne either 0 (off) or 1 (on), "invert" (also 0/1) control inversion of the input siognal polarity</p>
<br/>
<h4>los:port=level</h4>
<p>Configure input LOS (loss of signal) thershold level</p>
<table border="1">
<tr><th>level</th><th>threshold</th></tr>
<tr><td>0</td><td>---</td></tr>
<tr><td>1</td><td>---</td></tr>
<tr><td>2</td><td>150 mV</td></tr>
<tr><td>3</td><td>200 mV</td></tr>
<tr><td>4</td><td>250 mV</td></tr>
<tr><td>5</td><td>300 mV</td></tr>
<tr><td>6</td><td>---</td></tr>
<tr><td>7</td><td>---</td></tr>
</table>
<br/>
<h4>pre_long:port=level:decay</h4>
<p>Output pre-emphasis with 0.5ns-1.5ns decay, where. 4-bit level controls pre-emphasis amount from 0 (off) to 15 (6db), and decay - 3-bit decay, 0 corresponds to fastest (0.5ns) and 15 - slowest one (1.5ns).</p>
<br/>
<h4>pre_short:port=level:decay</h4>
<p>Output pre-emphasis with 0.03 ns-0.5 ns decay, where. 4-bit level controls pre-emphasis amount from 0 (off) to 15 (6db), and decay - 3-bit decay, 0 corresponds to fastest (0.03ns) and 15 - slowest one (0.5ns).</p>
<br/>

<h4>out_level:port=level</h4>
<p>Programs output power level - peak-to-peak differentioal voltage. These values have to be reduced when pre-emphasis is used as the actual signal adds the levels.</p>
<table border="1">
<tr><th>level</th><th>output voltage</th></tr>
<tr><td> 0</td><td>---</td></tr>
<tr><td> 1</td><td>---</td></tr>
<tr><td> 2</td><td>405 mV</td></tr>
<tr><td> 3</td><td>425 mV</td></tr>
<tr><td> 4</td><td>455 mV</td></tr>
<tr><td> 5</td><td>485 mV</td></tr>
<tr><td> 6</td><td>520 mv</td></tr>
<tr><td> 7</td><td>555 mv</td></tr>
<tr><td> 8</td><td>605 mv</td></tr>
<tr><td> 9</td><td>655 mv</td></tr>
<tr><td>10</td><td>720 mv</td></tr>
<tr><td>11</td><td>790 mv</td></tr>
<tr><td>12</td><td>890 mv</td></tr>
<tr><td>13</td><td>990 mv (no avail. in 103697A)</td></tr>
<tr><td>14</td><td>---</td></tr>
<tr><td>15</td><td>---</td></tr>
</table>
<br/>
<h4>out_state:port=mode:oob_forwarding</h4>
<p>Controls output inversion and OOB forwarding.'oob' of 1 enables, 0 - disables OOB forwarding and 'mode' can be one of</p>
<table border="1">
<tr><th>mode</th><th>Descrtiption</th></tr>
<tr><td>0</td><td>disabled</td></tr>
<tr><td>5</td><td>non-inverted</td></tr>
<tr><td>10</td><td>inverted</td></tr>
</table>

 

EOT;
}

/** Read the current state of the switch and place data to global variables */
function readCurrentState()
{
	global $debug, $channels, $param_paths;
	global $activeInputs, $activeOutputs;
	global $port_ise, $port_input_state, $port_los, $port_pre_long, $port_pre_short, $port_out_level;
	global $port_out_state, $port_channel_status, $port_channel_input;
	
	// read ISE
	if ($debug)
		echo "<!-- read ISE -->\n";
	$ise_short = read_vals($param_paths['input_ISE_short'] . port_fn());
	$ise_medium = read_vals($param_paths['input_ISE_medium'] . port_fn());
	$ise_long = read_vals($param_paths['input_ISE_long'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => " . 
			"short: " . $ise_short[$index] . ", " .
			"medium: " . $ise_medium[$index] . ", " .
			"long: " . $ise_long[$index] . " -->\n";
		$port_index = translate_index($index, 'in');
		$port_ise[$port_index] = array(
				'short' => $ise_short[$index],
				'medium' => $ise_medium[$index],
				'long' => $ise_long[$index]);
	}
	
	// read InputState
	if ($debug)
		echo "<!-- read InputState -->\n";
	$port_termination = read_vals($param_paths['input_terminate'] . port_fn());
	$port_invertion = read_vals($param_paths['input_invert'] . port_fn());
	$input_off = read_vals($param_paths['input_off'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => " . 
			"off: " . $input_off[$index] . ", " .
			"terminate: " . $port_termination[$index] . ", " .
			"invert: " . $port_invertion[$index] . " -->\n";
		$activeInputs[$index] = $input_off[$index] == 0;
		$port_index = translate_index($index, 'in');
		$port_input_state[$port_index] = array(
				'terminate' => $port_termination[$index],
				'invert' => $port_invertion[$index]);
	}

	// read LOS
	if ($debug)
		echo "<!-- read LOS -->\n";
	$data = read_vals($param_paths['input_LOS'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => " .
			"level: " . $data[$index] . " -->\n";
		$port_index = translate_index($index, 'in');
		$port_los[$port_index] = array('level' => $data[$index]);
	}

	// read pre-emphasis (long)
	if ($debug)
		echo "<!-- read pre-emphasis (long) -->\n";
	$data_level = read_vals($param_paths['output_PRE_long_level'] . port_fn());
	$data_decay = read_vals($param_paths['output_PRE_long_decay'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => " .
			"level: " . $data_level[$index] . ", " .
			"decay: " . $data_decay[$index] . " -->\n";
		$port_index = translate_index($index, 'out');
		$port_pre_long[$port_index] = array(
				'level' => $data_level[$index],
				'decay' => $data_decay[$index]);
	}
	
	// read pre-emphasis (short)
	if ($debug)
		echo "<!-- read pre-emphasis (short) -->\n";
	$data_level = read_vals($param_paths['output_PRE_short_level'] . port_fn());
	$data_decay = read_vals($param_paths['output_PRE_short_decay'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => " .
			"level: " . $data_level[$index] . ", " .
			"decay: " . $data_decay[$index] . " -->\n";
		$port_index = translate_index($index, 'out');
		$port_pre_short[$port_index] = array(
				'level' => $data_level[$index],
				'decay' => $data_decay[$index]);
	}

	// read output level
	if ($debug)
		echo "<!-- read output level -->\n";
	$data = read_vals($param_paths['output_level'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => " . 
			"level: " . $data[$index] . " -->\n";
		$port_index = translate_index($index, 'out');
		$port_out_level[$port_index] = array('level' => $data[$index]);
	}
	
	// read OutputState
	if ($debug)
		echo "<!-- read output state -->\n";
	$data_mode = read_vals($param_paths['output_mode'] . port_fn());
	$data_oob = read_vals($param_paths['forward_OOB'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => ".
			"mode: " . $data_mode[$index] . ", " .
			"OOB: " .$data_oob[$index] . " -->\n";
		$port_index = translate_index($index, 'out');
		$port_out_state[$port_index] = array(
				'mode' => $data_mode[$index],
				'oob' => $data_oob[$index]);
	}
	
	// read channel status
	if ($debug)
		echo "<!-- read channel status -->\n";
	$data = read_vals($param_paths['status'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "]" .
			"status: " . $data[$index] . " -->\n";
		$port_index = translate_index($index, 'in');
		$port_channel_status[$port_index] = array('los' => $data[$index]);
	}

	// read connections
	if ($debug)
		echo "<!-- read connections -->\n";
	$data = read_vals($param_paths['connections'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		if ($debug)
			echo "<!-- [" . $index . "] => ".
			"connection: " . $data[$index] . " -->\n";
		$port_index = translate_index($index, 'out');
		$val = (($data[$index] & 0x10) == 0) ? ($data[$index] & 0x0f) : -1;
		$port_channel_input[$port_index] = array('input' => $val);
		$activeOutputs[$index] = ($data[$index] & 0x10) == 0;
	}
}

function readCurrentState_old(){
 global $debug, $i2c_InterfaceMode,$i2c_InterfaceModeData,$SA;
 global $i2c_CurrentPage,$activeInputs,$activeOutputs;
 global $port_ise,$port_input_state,$port_los,$port_pre_long,$port_pre_short,$port_out_level;
 global $port_out_state,$port_channel_status,$port_channel_input;
 global $i2c_Page_InputISE, $i2c_Page_InputState,$i2c_Page_InputLOS,$i2c_Page_OutputPreLong,$i2c_Page_OutputPreShort;
 global $i2c_Page_OutputLevel, $i2c_Page_OutputState,$i2c_Page_ChannelStatus,$i2c_Page_Connection;
    if ($debug) echo '<!-- setting i2c mode (writing 0x'.dechex($i2c_InterfaceModeData).' to 0x'.dechex($SA | $i2c_InterfaceMode).' -->'."\n";
    i2c_send_or_die($i2c_InterfaceMode,$i2c_InterfaceModeData); // set i2c mode
// Read ISE
    if ($debug) echo "<!-- reading ISE -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_InputISE);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_ise[$index]=array(
       'short'=>($data>>4)&3,
       'medium'=>($data>>2)&3,
       'long'=>($data)&3);
    }
// Read InputState (program termination for inputs 8-11 during programming output
    if ($debug) echo "<!-- read InputState -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_InputState); // select page 0x11  ($i2c_Page_InputState)
    for ($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $activeInputs[$index]=($data & 2) == 0;
      $port_input_state[$index]= array(
        'terminate'=>((($data>>2)&1)==0)?1:0,
        'invert'=>   ($data   )&1);
    }
    // read LOS
    if ($debug) echo "<!-- read LOS -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_InputLOS);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_los[$index]=   array('level'=>$data);
    }

    // read pre-emphasis (long)
    if ($debug) echo "<!-- read pre-emphasis (long) -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputPreLong);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_pre_long[$index]=    array(
         'level'=>($data>>3)&0x0f,
         'decay'=> $data & 7);
    }

    // read pre-emphasis (short)
    if ($debug) echo "<!-- read pre-emphasis (short) -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputPreShort);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_pre_short[$index]=    array(
         'level'=>($data>>3)&0x0f,
         'decay'=> $data & 7);
    }

    // program output level and shared inputs (8..11) termination
    if ($debug) echo "<!-- read output level -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputLevel);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_out_level[$index]=    array(
         'level'=>$data& 0x0f);
     if ($index>=8){
      $data=i2c_get_or_die($index+4);
      if ($debug) echo "<!-- [".($index+4)."] => ".$data." -->\n";
       $port_input_state[$index]['terminate']=(($data & 0x10)==0)?0:1;
     }

    }

    // read Output State
    if ($debug) echo "<!-- read output state -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_OutputState);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_out_state[$index]=    array(
         'mode'=>($data>>1)& 0x0f,
         'oob'=> $data & 1);
    }

    // read Channel Status
    if ($debug) echo "<!-- read channel status -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_ChannelStatus);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_channel_status[$index]=    array(
         'los'=> $data & 1);
    }
   // Read connections
    if ($debug) echo "<!-- read connections -->\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_Connection);
    for($index=0;$index<12;$index++) {
      $data=i2c_get_or_die($index);
      if ($debug) echo "<!-- [".$index."] => ".$data." -->\n";
      $port_channel_input[$index]=    array(
         'input'=> (($data & 0x10)==0)?($data & 0x0f):-1);
      $activeOutputs[$index]=($data & 0x10)==0;
    }

}
// TODO: add XML version
function values_los_dedicated($index){
   $values =array(
   'invalid', // 0
   'invalid', // 1
   '150 mV',  // 2
   '200 mV',  // 3
   '250 mV',  // 4
   '300 mV',  // 5
   'invalid', // 6
   'invalid');// 7
   return $values[$index];
}
function values_los_bidirectional($index){
   $values =array(
   'invalid', // 0
   'invalid', // 1
   '170 mV',  // 2
   '230 mV',  // 3
   '280 mV',  // 4
   '330 mV',  // 5
   'invalid', // 6
   'invalid');// 7
   return $values[$index];
}
function values_ise($index){
   $values=array(
   'Off', // 0
   'Minimum', // 1
   'Moderate', // 2
   'Maximal');// 3
   return $values[$index];
}
function values_pre_level($index,$digits=1){
   $range=pow(10,6.0/20);
   $gain=1.0+ ($index & 0xf)*($range-1.0)/15;
   $level=20*log10($gain);
   return sprintf('%'.($digits+2).'.'.$digits.'f dB',$index);
}
function values_pre_long_decay($index){
   $min=500;
   $max=1500;
   $decay=$min+($index & 0x7)*($max-$min)/7;
   return round($decay).' ps';
}
function values_pre_short_decay($index,$digits=1){
   $min=30;
   $max=500;
   $decay=$min+($index & 0x7)*($max-$min)/7;
   return round($decay).' ps';
}
function values_output_level($index){
   $values =array(
   'invalid', // 0
   'invalid', // 1
   '405 mV',  // 2
   '425 mV',  // 3
   '455 mV',  // 4
   '485 mV',  // 5
   '520 mV',  // 6
   '555 mV',  // 7
   '605 mV',  // 8
   '655 mV',  // 9
   '720 mV',  //10
   '790 mV',  //11
   '890 mV',  //12
   '990 mV',  //13
   'invalid', //14
   'invalid');//15
   return $values[$index];
}
function values_outout_state($index){
   switch ($index) {
     case 0: return 'supressed';
     case 5: return 'normal';
     case 10: return 'inverted';
     default: return 'undefined';
   }
}


function showCurrentStateHTML(){
 global $debug;
 global $activeInputs,$activeOutputs,$channels;
 global $port_ise,$port_input_state,$port_los,$port_pre_long,$port_pre_short,$port_out_level;
 global $port_out_state,$port_channel_status,$port_channel_input;
 echo "<center><h1>SATA Multiplexer Current State</h1></center>\n";
 echo "<table border=\"1\">\n";
   echo "<tr>\n";
    echo "<th>Name</th>";
    echo "<th>Range</th>";
    for ($index=0;$index<count($channels);$index++) echo '<th>'.$channels[$index]['name'].'</th>';
   echo "</tr>\n";
   echo "<tr>\n";
    echo "<th>Connector</th>";
    echo "<td>J1...J11</td>";
    for ($index=0;$index<count($channels);$index++) echo '<td>J'.$channels[$index]['connector'].'</td>';
   echo "</tr>\n";
   echo "<tr>\n";
    echo "<th>Input</th>";
    echo "<td>&nbsp;</td>";
    for ($index=0;$index<count($channels);$index++) echo '<td>in-'.$channels[$index]['in'].'</td>';
   echo "</tr>\n";
   echo "<tr>\n";
    echo "<th>Output</th>";
    echo "<td>&nbsp;</td>";
    for ($index=0;$index<count($channels);$index++) echo '<td>out-'.$channels[$index]['out'].'</td>';
   echo "</tr>\n";
   echo "<tr>\n";
    if ($debug) {echo '<!-- port_channel_status:'; print_r($port_channel_status);echo "-->\n";}
    echo "<th>State</th>";
    echo "<td>LOS, active, ---</td>";
    for ($index=0;$index<count($channels);$index++){
        $los=(($port_channel_status[$channels[$index]['in']]['los']>0)?'LOS':'active');
        echo '<td>'.($activeInputs[$channels[$index]['in']]?$los:'---').'</td>';
    }
   echo "</tr>\n";
   echo "<tr>\n";
    if ($debug) {echo '<!-- port_channel_input:'; print_r($port_channel_input);echo "-->\n";}
    echo "<th>Input from</th>";
    echo "<td>&nbsp;</td>";
    for ($index=0;$index<count($channels);$index++) {
       $inChn=$port_channel_input[$channels[$index]['out']]['input'];
       $portIndex=inputChannelToIndex($inChn);
       echo '<td>'.(($inChn<0)?"---":(($portIndex>=0)?$channels[$portIndex]['name']:('?'.$inChn))).'</td>';
    }

   echo "</tr>\n";
   echo "<tr>\n";
    echo "<th>LOS threshold</th>";
    echo "<td>2-5</td>";
    if ($debug) {echo '<!-- port_los:'; print_r($port_los);echo "-->\n";}
    for ($index=0;$index<count($channels);$index++){
      $los_index=$port_los[$channels[$index]['in']]['level'];
      $los_value=($channels[$index]['in']>=8)?values_los_bidirectional($los_index):values_los_dedicated($los_index);
      echo '<td>'.$los_index.': '.$los_value.'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>ISE short</th>";
    echo "<td>0-3</td>";
    if ($debug) {echo '<!-- port_ise:'; print_r($port_ise);echo "-->\n";}
    for ($index=0;$index<count($channels);$index++) {
      $ise_index=$port_ise[$channels[$index]['in']]['short'];
      echo '<td>'.$ise_index.': '.values_ise($ise_index).'</td>';
    }
   echo "</tr>\n";


   echo "<tr>\n";
    echo "<th>ISE medium</th>";
    echo "<td>0-3</td>";
    for ($index=0;$index<count($channels);$index++) {
      $ise_index=$port_ise[$channels[$index]['in']]['medium'];
      echo '<td>'.$ise_index.': '.values_ise($ise_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>ISE long</th>";
    echo "<td>0-3</td>";
    for ($index=0;$index<count($channels);$index++) {
      $ise_index=$port_ise[$channels[$index]['in']]['long'];
      echo '<td>'.$ise_index.': '.values_ise($ise_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    if ($debug) {echo '<!-- port_input_state:'; print_r($port_input_state);echo "-->\n";}
    echo "<th>Input terminate</th>";
    echo "<td>yes/no</td>";
    for ($index=0;$index<count($channels);$index++) echo '<td>'.(($port_input_state[$channels[$index]['in']]['terminate']>0)?'yes':'no').'</td>';
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Input invert</th>";
    echo "<td>yes/no</td>";
    for ($index=0;$index<count($channels);$index++) echo '<td>'.(($port_input_state[$channels[$index]['in']]['invert']>0)?'yes':'no').'</td>';
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Preemphasis level (long)</th>";
    echo "<td>0..15</td>";
    if ($debug) {echo '<!-- port_pre_long:'; print_r($port_pre_long);echo "-->\n";}
    for ($index=0;$index<count($channels);$index++){
      $level_index=$port_pre_long[$channels[$index]['out']]['level'];
      echo '<td>'.$level_index.': '.values_pre_level($level_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Preemphasis decay (long)</th>";
    echo "<td>0..7</td>";
    for ($index=0;$index<count($channels);$index++){
      $decay_index=$port_pre_long[$channels[$index]['out']]['decay'];
      echo '<td>'.$decay_index.': '.values_pre_long_decay($decay_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Preemphasis level (short)</th>";
    echo "<td>0..15</td>";
    if ($debug) {echo '<!-- port_pre_short:'; print_r($port_pre_short);echo "-->\n";}
    for ($index=0;$index<count($channels);$index++){
      $level_index=$port_pre_short[$channels[$index]['out']]['level'];
      echo '<td>'.$level_index.': '.values_pre_level($level_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Preemphasis decay (short)</th>";
    echo "<td>0..7</td>";
    for ($index=0;$index<count($channels);$index++){
      $decay_index=$port_pre_short[$channels[$index]['out']]['decay'];
      echo '<td>'.$decay_index.': '.values_pre_short_decay($decay_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Output level</th>";
    echo "<td>2..13</td>";
    if ($debug) {echo '<!-- port_out_level:'; print_r($port_out_level);echo "-->\n";}
    for ($index=0;$index<count($channels);$index++) {
      $level_index=$port_out_level[$channels[$index]['out']]['level'];
      echo '<td>'.$level_index.': '.values_output_level($level_index).'</td>';
    }
   echo "</tr>\n";

   echo "<tr>\n";
    echo "<th>Output mode</th>";
    echo "<td>0,5,10</td>";
    for ($index=0;$index<count($channels);$index++){
      $mode_index=$port_out_state[$channels[$index]['out']]['mode'];
      echo '<td>'.$mode_index.': '.values_outout_state($mode_index).'</td>';
    }
   echo "</tr>\n";
   echo "<tr>\n";
    echo "<th>OOB forward</th>";
    echo "<td>On/Off</td>";
    for ($index=0;$index<count($channels);$index++) echo '<td>'.(($port_out_state[$channels[$index]['out']]['oob']>0)?'On':'Off').'</td>';
   echo "</tr>\n";
 echo "</table>\n";
}

function inputChannelToIndex($inChn) {
   global $channels;
   for ($index=0;$index<count($channels);$index++) if ($channels[$index]['in']== $inChn) return $index;
   return -1;
}
function outChannelToIndex($outChn) {
   global $channels;
   for ($index=0;$index<count($channels);$index++) if ($channels[$index]['out']== $outChn) return $index;
   return -1;
}

function data_ise($index){
   global $port_ise;
   return (($port_ise[$index]['short'] & 3)<<4) | (($port_ise[$index]['medium'] & 3)<<2) | ($port_ise[$index]['long'] & 3);
}

function data_input_state($index){ // need special treatment for ports 8..11 and combining with active input?
   global $port_input_state,$activeInputs;
   $poweroff=($index<0) || !$activeInputs[$index]; // poweroff if all, individual - inactive
   return (($port_input_state[$index]['terminate'] >0)?0:4) | (($port_input_state[$index]['invert'] >0)?1:0) | ($poweroff? 2:0);
}

function data_port_los($index){
   global $port_los;
   return $port_los[$index]['level'] & 7;
}

function data_pre_long($index){
   global $port_pre_long;
   return (($port_pre_long[$index]['level'] & 0x0f)<<3) | ($port_pre_long[$index]['decay'] & 7);
}

function data_pre_short($index){
   global $port_pre_short;
   return (($port_pre_short[$index]['level'] & 0x0f)<<3) | ($port_pre_short[$index]['decay'] & 7);
}

function data_out_level($index){ // combine with inputs 8..11
   global $port_out_level;
   return $port_out_level[$index]['level'] & 0x0f;
}

function data_out_state($index){ // combine with inputs 8..11
   global $port_out_state;
   return (($port_out_state[$index]['mode'] & 0x0f)<<1) | ($port_out_state[$index]['oob']? 1:0);
}




function isIndividualSet($array){
  for ($i=0;$i<12;$i++) if (isset($array[$i]) )return true;
  return false;
}
function isGlobalSet($array){
  if (isset($array[-1])) return true;
  return false;
}

function i2c_send_or_die($reg,$data){
   global $BUS,$SA,$debug,$dry;
   if ($debug) echo '<!--      '.($dry?'Simulating writing':'Writing').' to register 0x'.dechex($SA | $reg).', data=0x'.dechex($data)."-->\n";
   if ($dry) return;
   $rslt=i2c_send(8,$BUS,$SA | $reg, $data);
   if (!($rslt>0)) exitError('i2c write error to register 0x'.dechex($SA | $reg).', data=0x'.dechex($data).', returned '.$rslt.'\n'); // will exit
}
function i2c_get_or_die($reg){
   global $BUS,$SA,$debug,$dry;
   if ($debug) echo '<!--      '.($dry?'Simulating reading':'Reading').' register 0x'.dechex($SA | $reg)."-->\n";
   if ($dry) return 0;
//function i2c_receive($width,$bus,$a,$raw=0) {
   $rslt=i2c_receive(8,$BUS,$SA | $reg);
   if (!($rslt>=0)) exitError('i2c read error from register 0x'.dechex($SA | $reg).'\n'); // will exit
   return $rslt;
}


function getMultiVals($value){
   $aval=explode(':',$value);
   for ($i=0;$i<count($aval);$i++) $aval[$i]+=0;
   return $aval;
}


function programConnections($disableUnused){
  global $debug,$channels,$connections,$activeOutputs,$activeInputs,$BUS,$SA, $i2c_CurrentPage,$i2c_Page_Connection,$i2c_Page_InputState,$i2c_Page_OutputLevel; // in init mode all the unused connections will be powered down
    if ($debug) echo '<!-- selecting Page Connection -->'."\n";
    i2c_send_or_die($i2c_CurrentPage,$i2c_Page_Connection); // select page 0  ($i2c_Page_Connection)
    foreach ($connections as $connection) {
      if ($debug) {
        echo '<!-- connection in['.$channels[$connection[0]]['in'].'] -> out['.$channels[$connection[1]]['out'].']-->'."\n";
        echo '<!-- connection in['.$channels[$connection[1]]['in'].'] -> out['.$channels[$connection[0]]['out'].']-->'."\n";
      }
      i2c_send_or_die($channels[$connection[1]]['out'],$channels[$connection[0]]['in']);  // connect out to ssd to in from host
      i2c_send_or_die($channels[$connection[0]]['out'],$channels[$connection[1]]['in']);  // connect out to host to in from ssd
    }
// disable unused outputs
   if ($disableUnused) {
    $disabledConnection=0x10;
     for ($i=0;$i<count($activeOutputs);$i++) if (!$activeOutputs[$i]) {
       if ($debug) echo '<!-- disabling unused output'.$i.' -->'."\n";
       i2c_send_or_die($i, $disabledConnection);  // connect out to ssd to in from host
     }
   }
}



function listSettings(){
  global $debug,$channels,$connections;
    echo "<h4>Connections</h4>\n<ul>";
  foreach ($connections as $connection) {
    echo '<li>'.$channels[$connection[0]]['name'].' ( J'.$channels[$connection[0]]['connector'].' ) <==> '.
                $channels[$connection[1]]['name'].' ( J'.$channels[$connection[1]]['connector'].' ):   '."\t".
                'in['.$channels[$connection[0]]['in'].'] -> out['.$channels[$connection[1]]['out'].'];   '."\t". 
                'in['.$channels[$connection[1]]['in'].'] -> out['.$channels[$connection[0]]['out'].'] </li>'."\n";
  }
  echo "</ul>\n";
}
function parsePort($name){
  global $debug,$channels;
  if ((strtolower($name)=='global') || (strtolower($name)=='all')) {
    return -1;
  }
  for ($i=0;$i<count($channels);$i++) if ((strtolower($name)==strtolower($channels[$i]['name'])) || (strtolower($name)==('j'.strtolower($channels[$i]['connector'])))){
     return $i;
  }
  $a=sscanf($name,"%d");
  return ($a[0]); 
}

function parseInPort($name){
  global $debug,$channels;
  if ((strtolower($name)=='global') || (strtolower($name)=='all')) {
    return -1;
  }
  for ($i=0;$i<count($channels);$i++) if ((strtolower($name)==strtolower($channels[$i]['name'])) || (strtolower($name)==('j'.strtolower($channels[$i]['connector'])))){
     return $channels[$i]['in'];
  }
  $a=sscanf($name,"%d");
  return ($a[0]); 
}
function parseOutPort($name){
  global $debug,$channels;
  if ((strtolower($name)=='global') || (strtolower($name)=='all')) {
    return -1;
  }
  for ($i=0;$i<count($channels);$i++) if ((strtolower($name)==strtolower($channels[$i]['name'])) || (strtolower($name)==('j'.strtolower($channels[$i]['connector'])))){
     return $channels[$i]['out'];
  }
  $a=sscanf($name,"%d");
  return ($a[0]); 
}


function exitError($text){
   global $debug;
   if (!$debug) echo "<pre>\n";
   $debug=true;
   echo $text;
   echo "</pre>\n";
   exit (1);
}

/** Create port file name from port number */
function port_fn($port_num = -1)
{
	if ($port_num == -1)
		return "all";
	else
		return printf("port_%02d", $port_num);
}

/** Read one string from sysfs file, split it and return an array of values */
function read_vals($file_name)
{
	$substr = array();
	$f = fopen($file_name, 'r');
	if ($f !== false) {
		if (($data = fgets($f)) !== false) {
			$data = str_replace("\n", "", $data);
			$substr = preg_split("/ +/", $data);
		}		
		fclose($f);
	}
	
	return $substr;
}

/** Find port index in the channels list by zero based index given */
function translate_index($index, $dir)
{
	global $channels;
	$port_index = -1;
	$offset = 8;                  // VSC3304 port numbering starts from 08, the offset is used to minimize legacy code modifications 
	$ret = -1;
	
	
	for ($i = 0; $i < count($channels); $i++) {
		if ($channels[$i][$dir] == ($index + $offset))
			$port_index = $i;
	}
	if ($port_index != -1) {
		$ret = $channels[$port_index][$dir];
	}
	
	return $ret;
}

?> 
