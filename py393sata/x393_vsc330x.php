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

$debug=false;
$vsc_sysfs_dir = '/sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0/0-0001';
$connections=array(); // pairs, first index< second

$pcb_connections = array(
		'ESATA_A' => 'A',
		'ESATA_B' => 'C',
		'SSD_A'   => 'E',
		'SSD_B'   => 'F',
		'ZYNQ_A'  => 'G',
		'ZYNQ_B'  => 'H'
);

// I/O pairs for the same physical port
$port_num = array(
		'A' => array('in' => 12, 'out' => 8),
		'B' => array('in' => 13, 'out' => 9),
		'C' => array('in' => 14, 'out' => 10),
		'D' => array('in' => 15, 'out' => 11),
		'E' => array('in' => 8,  'out' => 12),
		'F' => array('in' => 9,  'out' => 13),
		'G' => array('in' => 10, 'out' => 14),
		'H' => array('in' => 11, 'out' => 15)
);

$channels = array(
		array('in' => $port_num[$pcb_connections['ESATA_A']]['in'], 
			 'out' => $port_num[$pcb_connections['ESATA_B']]['out'],
			 'name'=>'ESATA', 'connector' => 'ESATA',
			 'phy_ports' => array('ESATA_A', 'ESATA_B')),
        array('in' => $port_num[$pcb_connections['SSD_B']]['in'],
        	 'out' => $port_num[$pcb_connections['SSD_A']]['out'],
        	 'name'=>'SSD',   'connector' => 'SSD',
        	 'phy_ports' => array('SSD_A', 'SSD_B')),
        array('in' => $port_num[$pcb_connections['ZYNQ_A']]['in'],
        	 'out' => $port_num[$pcb_connections['ZYNQ_B']]['out'],
        	 'name'=>'ZYNQ',  'connector' => 'ZYNQ',
        	 'phy_ports' => array('ZYNQ_A', 'ZYNQ_B')));

$vsc3304_connections = array(
		'ZYNQ<->SSD'   => array(array('FROM' => 'ZYNQ_A', 'TO'  => 'SSD_A'),
								array('FROM' => 'SSB_B',  'TO'  => 'ZYNQ_B')),
		'ZYNQ<->ESATA' => array(array('FROM' => 'ZYNQ_A', 'TO'  => 'ESATA_A'),
								array('FROM' => 'ESATA_B', 'TO' => 'ZYNQ_B')),
		'ZYNQ<->SSATA' => array(array('FROM' => 'ZYNQ_A', 'TO'  => 'ESATA_B'),
								array('FROM' => 'ESATA_A', 'TO' => 'ZYNQ_B')),
		'ESATA<->SSD'  => array(array('FROM' => 'SSD_B', 'TO'   => 'ESATA_B'),
								array('FROM' => 'ESATA_A', 'TO' => 'SSD_A'))
);

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

$default_out_levels = array(
		'ESATA_A' => 3,
		'ESATA_B' => 3,
		'SSD_B'   => 2,
		'ZYNQ_A'  => 2
);

$default_inverted_ports = array(
		'A', 'E', 'G', 'H'
);

if (count($_GET) == 0) {
	showUsage();
	exit(0);
}

$debug= isset($_GET['debug']);
$init= !isset($_GET['noinit']); // default - on
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
// define the types of data in arrays
$port_ise['type']            = 'in';
$port_input_state['type']    = 'in';
$port_los['type']            = 'in';
$port_pre_long['type']       = 'out';
$port_pre_short['type']      = 'out';
$port_out_level['type']      = 'out';
$port_out_state['type']      = 'out';
$port_channel_status['type'] = 'in';
$port_channel_input['type']  = 'out';
if ($init) {
 	$port_ise[-1]=         array('short'=>0,'medium'=>0,'long'=>0);
	$port_ise[-1]=         array('short'=>0,'medium'=>0,'long'=>0);
	$port_los[-1]=         array('level'=>4); // 250 mv
	$port_pre_long[-1]=    array('level'=>0,'decay'=>0);
	$port_pre_short[-1]=   array('level'=>0,'decay'=>0);
	
	// set the value that the register has after reset 
	$vals = array();
	for ($i = 0; $i < count($port_num); $i++)
		$vals[index_to_port_num($i)] = 1;
	// apply default values
	foreach ($default_out_levels as $phy_port => $level) {
		$index = $port_num[$pcb_connections[$phy_port]]['out'];
		$vals[$index] = $level;
	}
	$port_out_level[-1] = array('level' => $vals);
	
	// set the value that the register has after reset
	$vals = array();
	for ($i = 0; $i < count($port_num); $i++)
		$vals[index_to_port_num($i)] = 0;
	// apply default values
	foreach ($default_inverted_ports as $phy_port) {
		$index = $port_num[$phy_port]['in'];
		$vals[$index] = 1;
	}
	$port_input_state[-1] = array('terminate' => 0, 'invert' => $vals);
	
	// set the value that the register has after reset
	$vals = array();
	for ($i = 0; $i < count($port_num); $i++)
		$vals[index_to_port_num($i)] = 5;
	// apply default values
	foreach ($default_inverted_ports as $phy_port) {
		$index = $port_num[$phy_port]['out'];
		$vals[$index] = 10;
	}
	$port_out_state[-1] = array('mode' => $vals, 'oob' => 1);

}


update_chn_from_sysfs();
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
       if (($pair[0]>=0) &&
           ($pair[0]<count($channels)) &&
           ($pair[1]>=0) &&
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
          set_channels($key, $value, $GLOBALS['vsc3304_connections'], $GLOBALS['port_num'], $GLOBALS['pcb_connections'], $channels);
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
      if (($inPort>=-1) && ($inPort <= max_port_num('in'))) $port_ise[$inPort]=$this_ise;
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
      if (($inPort>=-1) && ($inPort <= max_port_num('in'))) $port_input_state[$inPort]=$this_input_state;
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
      if (($inPort>=-1) && ($inPort <= max_port_num('in'))) $port_los[$inPort]=array('level'=>$aval[0]);
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
      if (($outPort>=-1) && ($outPort <= max_port_num($port_pre_long['type']))) $port_pre_long[$outPort]=$this_pre_long;
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
      if (($outPort>=-1) && ($outPort <= max_port_num($port_pre_short['type']))) $port_pre_short[$outPort]=$this_pre_short;
      else {
        echo "Invalid output port index=$outPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
    case 'OUT_LEVEL':
      $aval=getMultiVals($value);
      if ((count($aval)!=1) || ($aval[0]<0) || ($aval[0]>15)) {
        echo "Value for the OUT_LEVEL (output signal level) command is expected to be  0..15 value, got >$value<\n";
        $error =true;
        exit (1);
      }
      $this_out_level=array('level'=>$aval[0]);
      if (($outPort>=-1) && ($outPort <= max_port_num($port_out_level['type']))) $port_out_level[$outPort]=$this_out_level;
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
      if (($outPort>=-1) && ($outPort <= max_port_num($port_out_state['type']))) $port_out_state[$outPort]=$this_out_state;
      else {
        echo "Invalid output port index=$outPort\n";
        $error =true;
        exit (1);
      }
      if ($debug) {
      }
    break;
  }
}
	
if (isset($_GET['list']))
	listSettings();
foreach ($port_num as $pn) {
	$activeOutputs[$pn['out']] = false;
	$activeInputs[$pn['in']] = false;
};
foreach ($connections as $connection) {
	$activeOutputs[$channels[$connection[0]]['out']] = true;
	$activeOutputs[$channels[$connection[1]]['out']] = true;
	$activeInputs[$channels[$connection[0]]['in']] = true;
	$activeInputs[$channels[$connection[1]]['in']] = true;
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

// program ISE
if ($debug)
	echo "<!-- program ISE -->\n";
if (isGlobalSet($port_ise)) {
	$all_ise_short = $port_ise[-1]['short'];
	write_vals($param_paths['input_ISE_short'] . 'all', $all_ise_short);
	$all_ise_medium = $port_ise[-1]['medium'];
	write_vals($param_paths['input_ISE_medium'] . 'all', $all_ise_medium);
	$all_ise_long = $port_ise[-1]['long'];
	write_vals($param_paths['input_ISE_long'] . 'all', $all_ise_long);
}
if (isIndividualSet($port_ise)) {
	for ($index = 0; $index < count($channels); $index++) {
		$port_num = $channels[$index][$port_ise['type']];
		if (isset($port_ise[$port_num])) {
			write_vals($param_paths['input_ISE_short'] . port_fn($port_num), $port_ise[$port_num]['short']);
			write_vals($param_paths['input_ISE_medium'] . port_fn($port_num), $port_ise[$port_num]['medium']);
			write_vals($param_paths['input_ISE_long'] . port_fn($port_num), $port_ise[$port_num]['long']);
		}
	}
}
	
// program InputState
if ($debug)
	echo "<!-- program InputState -->\n";
$default_inv = array();
if (isGlobalSet($port_input_state)) {
	// default polarity invertion can be specified without init, it will be applied for inputs that 
	// are programmed anyway
	$default_inv = data_input_invert(-1);
}
// scan all inputs and disable/inable them only in init mode
for ($index = 0; $index < count($channels); $index++) {
	$port_num = $channels[$index][$port_input_state['type']];
	$power_on = $activeInputs[$channels[$index]['in']] || isset($port_input_state[$port_num]); // programming input implies it is on
	if (!empty($default_inv))
		$invert_value = $default_inv[$port_num];
	else
		$invert_value = 0;
	if (isset($port_input_state[$port_num])) {
		$invert_value = data_input_invert($port_num);
	}
	if ($init || $power_on) {
		$power_value = ($power_on) ? 0 : 1;
		write_vals($param_paths['input_off'] . port_fn($port_num), $power_value);
		write_vals($param_paths['input_invert'] . port_fn($port_num), $invert_value);
	}
}

// program input termination
if ($debug)
	echo "<!-- program input termination -->\n";
if (isGlobalSet($port_input_state)) {
	$all_terminate = data_input_terminate(-1);
	write_vals($param_paths['input_terminate'] . 'all', $all_terminate);
}
if (isIndividualSet($port_input_state)) {
	for ($index = 0; $index < count($channels); $index++) {
		$port_num = $channels[$index][$port_input_state['type']];
		if (isset($port_input_state[$port_num])) {
			write_vals($param_paths['input_terminate'] . port_fn($port_num), data_input_terminate($port_num));
		}
	}
}

// program LOS
if ($debug)
	echo "<!-- program LOS -->\n";
if (isGlobalSet($port_los)) {
	$all_los = data_port_los(-1);
	write_vals($param_paths['input_LOS'] . 'all', $all_los);
}
if (isIndividualSet($port_los)) {
	for ($index = 0; $index < count($channels); $index ++) {
		$port_num = $channels[$index][$port_los['type']];
		if (isset($port_los[$port_num])) {
			write_vals($param_paths['input_LOS'] . port_fn($port_num), data_port_los($port_num));
		}
	}
}

// program pre-emphasis (long)
if ($debug)
	echo "<!-- program pre-emphasis (long) -->\n";
if (isGlobalSet($port_pre_long)) {
	$all_pre_long_decay = data_pre_long_decay(-1);
	$all_pre_long_level = data_pre_long_level(-1);
	write_vals($param_paths['output_PRE_long_decay'] . 'all', $all_pre_long_decay);
	write_vals($param_paths['output_PRE_long_level'] . 'all', $all_pre_long_level);
}
if (isIndividualSet($port_pre_long)) {
	for ($index = 0; $index < count($channels); $index++) {
		$port_num = $channels[$index][$port_pre_long['type']];
		if (isset($port_pre_long[$port_num])) {
			write_vals($param_paths['output_PRE_long_decay'] . port_fn($port_num), data_pre_long_decay($port_num));
			write_vals($param_paths['output_PRE_long_level'] . port_fn($port_num), data_pre_long_level($port_num));
		}
	}
}

// program pre-emphasis (short)
if ($debug)
	echo "<!-- program pre-emphasis (short) -->\n";
if (isGlobalSet($port_pre_short)) {
	$all_pre_short_decay = data_pre_short_decay(-1);
	$all_pre_short_level = data_pre_short_level(-1);
	write_vals($param_paths['output_PRE_short_decay'] . 'all', $all_pre_short_decay);
	write_vals($param_paths['output_PRE_short_level'] . 'all', $all_pre_short_level);
}
if (isIndividualSet($port_pre_short)) {
	for ($index = 0; $index < count($channels); $index++) {
		$port_num = $channels[$index][$port_pre_short['type']];
		if (isset($port_pre_short[$port_num])) {
			write_vals($param_paths['output_PRE_short_decay'] . port_fn($port_num), data_pre_short_decay($port_num));
			write_vals($param_paths['output_PRE_short_level'] . port_fn($port_num), data_pre_short_level($port_num));
		}
	}
}

// program output level
if ($debug)
	echo "<!-- program output level -->\n";
if (isGlobalSet($port_out_level)) {
	$all_out_level = data_out_level(-1);
	foreach ($all_out_level as $port_num => $level) {		
		write_vals($param_paths['output_level'] . port_fn($port_num), $level);
	}
}
if (isIndividualSet($port_out_level)) {
	for ($index = 0; $index < count($channels); $index++) {
		$port_num = $channels[$index][$port_out_level['type']];
		if (isset($port_out_level[$port_num])) {
			write_vals($param_paths['output_level'] . port_fn($port_num), data_out_level($port_num));
		}
	}
}
	
// program Output State
if ($debug)
	echo "<!-- program output state -->\n";
if (isGlobalSet($port_out_state)) {
	$all_out_state = data_out_state(-1);
	$all_oob_state = data_oob_state(-1);
	write_vals($param_paths['forward_OOB'] . 'all', $all_oob_state);
	foreach ($all_out_state as $port_num => $state) {
		write_vals($param_paths['output_mode'] . port_fn($port_num), $state);
	}
}
if (isIndividualSet($port_out_state)) {
	for ($index = 0; $index < count($channels); $index++) {
		$port_num = $channels[$index][$port_out_state['type']];
		if (isset($port_out_state[$port_num])) {
			write_vals($param_paths['output_mode'] . port_fn($port_num), data_out_state($port_num));
			write_vals($param_paths['forward_OOB'] . port_fn($port_num), data_oob_state($port_num));
		}
	}
}

if ($debug)
	echo "<!-- program connections($init) -->\n";
programConnections($init); // in init mode will disable unused outputs

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
 <li><i>debug</i> - output additional information, such as the content of arrays, as HTML comments (visible with "view source" menu option in browser)</li>
 <li><i>noinit</i> - update only what is specified, do not disable unused i/o</li>
 <li><i>state</i> - show current programmed state of the multiplexer</li>
 <li><i><a href="$prefix_url?source">source</a></i> - show program source code (no other actions)</li>
</ul>
<h3>Commands with parameters</h3>
<p>All commands with parameters have format:</p>
<p><b>command:port=value</b>, where port can be specified in one of the following ways:</p>
<ul>
 <li><i>name</i> - name of a port as given in the "state" table header (i.e. SSD or ESATA)</li>
 <li><i>global</i> or <i>all</i> - apply to all ports (not valid for "connection" command).</ul>
<br/>
<h4>connection:port1=port2<br/>c:port1=port2</h4>
<p>Connect two ports. The order of the ports is arbitrary. If <i>noinit</i> does not appear in the url, all unused inputs and outputs will be disabled to 
 reduce power consumption.</p>
<br/>
<h4>ise:port=short_value:medium_value:long_value</h4>
<p>Configure ISE (input signal equalization) levels for short, medium and long time constants. Each value is in the range 0..3 (0- off, 1 - minimal, 
 2 - moderate, 3 - maximal)</p>
<br/>
<h4>in_state:port=terminate:invert</h4>
<p>Configure input port state. "terminate" (terminate input to VCC) can be either 0 (off) or 1 (on), "invert" (also 0/1) control inversion of 
 the input signal polarity</p>
<br/>
<h4>los:port=level</h4>
<p>Configure input LOS (loss of signal) threshold level</p>
<table border="1">
<tr><th>level</th><th>threshold</th></tr>
<tr><td>0</td><td>---</td></tr>
<tr><td>1</td><td>---</td></tr>
<tr><td>2</td><td>170 mV</td></tr>
<tr><td>3</td><td>230 mV</td></tr>
<tr><td>4</td><td>280 mV</td></tr>
<tr><td>5</td><td>330 mV</td></tr>
<tr><td>6</td><td>---</td></tr>
<tr><td>7</td><td>---</td></tr>
</table>
<br/>
<h4>pre_long:port=level:decay</h4>
<p>Output pre-emphasis with 0.5ns-1.5ns decay, where 4-bit level controls pre-emphasis amount from 0 (off) to 15 (6db), and decay - 3-bit decay, 
 0 corresponds to fastest (0.5ns) and 15 - slowest one (1.5ns).</p>
<br/>
<h4>pre_short:port=level:decay</h4>
<p>Output pre-emphasis with 0.03 ns-0.5 ns decay, where 4-bit level controls pre-emphasis amount from 0 (off) to 15 (6db), and decay - 3-bit decay, 
 0 corresponds to fastest (0.03ns) and 15 - slowest one (0.5ns).</p>
<br/>

<h4>out_level:port=level</h4>
<p>Programs output power level - peak-to-peak differential voltage. These values have to be reduced when pre-emphasis is used as the actual signal 
 adds the levels.</p>
<table border="1">
<tr><th>level</th><th>output voltage</th></tr>
<tr><td> 0</td><td>---</td></tr>
<tr><td> 1</td><td>---</td></tr>
<tr><td> 2</td><td>405 mV</td></tr>
<tr><td> 3</td><td>425 mV</td></tr>
<tr><td> 4</td><td>455 mV</td></tr>
<tr><td> 5</td><td>485 mV</td></tr>
<tr><td> 6</td><td>520 mV</td></tr>
<tr><td> 7</td><td>555 mV</td></tr>
<tr><td> 8</td><td>605 mV</td></tr>
<tr><td> 9</td><td>655 mV</td></tr>
<tr><td>10</td><td>720 mV</td></tr>
<tr><td>11</td><td>790 mV</td></tr>
<tr><td>12</td><td>890 mV</td></tr>
<tr><td>13</td><td>990 mV (3.3 V supply required)</td></tr>
<tr><td>14</td><td>---</td></tr>
<tr><td>15</td><td>---</td></tr>
</table>
<br/>
<h4>out_state:port=mode:oob_forwarding</h4>
<p>Controls output inversion and OOB forwarding. 'oob' of 1 enables, 0 - disables OOB forwarding and 'mode' can be one of</p>
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
		$port_index = translate_index($index, $port_ise['type']);
		if ($debug)
			echo "<!-- [" . $port_index . "] => " . 
			"short: " . $ise_short[$port_index] . ", " .
			"medium: " . $ise_medium[$port_index] . ", " .
			"long: " . $ise_long[$port_index] . " -->\n";
		$port_ise[$channels[$index][$port_ise['type']]] = array(
				'short' => $ise_short[$port_index],
				'medium' => $ise_medium[$port_index],
				'long' => $ise_long[$port_index]);
	}
	
	// read InputState
	if ($debug)
		echo "<!-- read InputState -->\n";
	$port_termination = read_vals($param_paths['input_terminate'] . port_fn());
	$port_invertion = read_vals($param_paths['input_invert'] . port_fn());
	$input_off = read_vals($param_paths['input_off'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_input_state['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => " . 
			"off: " . $input_off[$port_index] . ", " .
			"terminate: " . $port_termination[$port_index] . ", " .
			"invert: " . $port_invertion[$port_index] . " -->\n";
		$activeInputs[$channels[$index]['in']] = $input_off[$port_index] == 0;
		$port_input_state[$channels[$index][$port_input_state['type']]] = array(
				'terminate' => $port_termination[$port_index],
				'invert' => $port_invertion[$port_index]);
	}

	// read LOS
	if ($debug)
		echo "<!-- read LOS -->\n";
	$data = read_vals($param_paths['input_LOS'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_los['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => " .
			"level: " . $data[$port_index] . " -->\n";
		$port_los[$channels[$index][$port_los['type']]] = array('level' => $data[$port_index]);
	}

	// read pre-emphasis (long)
	if ($debug)
		echo "<!-- read pre-emphasis (long) -->\n";
	$data_level = read_vals($param_paths['output_PRE_long_level'] . port_fn());
	$data_decay = read_vals($param_paths['output_PRE_long_decay'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_pre_long['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => " .
			"level: " . $data_level[$port_index] . ", " .
			"decay: " . $data_decay[$port_index] . " -->\n";
		$port_pre_long[$channels[$index][$port_pre_long['type']]] = array(
				'level' => $data_level[$port_index],
				'decay' => $data_decay[$port_index]);
	}
	
	// read pre-emphasis (short)
	if ($debug)
		echo "<!-- read pre-emphasis (short) -->\n";
	$data_level = read_vals($param_paths['output_PRE_short_level'] . port_fn());
	$data_decay = read_vals($param_paths['output_PRE_short_decay'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_pre_short['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => " .
			"level: " . $data_level[$port_index] . ", " .
			"decay: " . $data_decay[$port_index] . " -->\n";
		$port_pre_short[$channels[$index][$port_pre_short['type']]] = array(
				'level' => $data_level[$port_index],
				'decay' => $data_decay[$port_index]);
	}

	// read output level
	if ($debug)
		echo "<!-- read output level -->\n";
	$data = read_vals($param_paths['output_level'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_out_level['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => " . 
			"level: " . $data[$port_index] . " -->\n";
		$port_out_level[$channels[$index][$port_out_level['type']]] = array('level' => $data[$port_index]);
	}
	
	// read OutputState
	if ($debug)
		echo "<!-- read output state -->\n";
	$data_mode = read_vals($param_paths['output_mode'] . port_fn());
	$data_oob = read_vals($param_paths['forward_OOB'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_out_state['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => ".
			"mode: " . $data_mode[$port_index] . ", " .
			"OOB: " .$data_oob[$port_index] . " -->\n";
		$port_out_state[$channels[$index][$port_out_state['type']]] = array(
				'mode' => $data_mode[$port_index],
				'oob' => $data_oob[$port_index]);
	}
	
	// read channel status
	if ($debug)
		echo "<!-- read channel status -->\n";
	$data = read_vals($param_paths['status'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_channel_status['type']);
		if ($debug)
			echo "<!-- [" . $index . "]" .
			"status: " . $data[$port_index] . " -->\n";
		$port_channel_status[$channels[$index][$port_channel_status['type']]] = array('los' => $data[$port_index]);
	}

	// read connections
	if ($debug)
		echo "<!-- read connections -->\n";
	$data = read_vals($param_paths['connections'] . port_fn());
	for ($index = 0; $index < count($channels); $index++) {
		$port_index = translate_index($index, $port_channel_input['type']);
		if ($debug)
			echo "<!-- [" . $index . "] => ".
			"connection: " . $data[$port_index] . " -->\n";
		echo "<!-- port_index: " . $port_index . " -->\n";
		$val = (($data[$port_index] & 0x10) == 0) ? ($data[$port_index] & 0x0f) : -1;
		$port_channel_input[$channels[$index][$port_channel_input['type']]] = array('input' => $val);
		$activeOutputs[$channels[$index]['out']] = ($data[$port_index] & 0x10) == 0;
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

function data_port_los($index)
{
	return $GLOBALS['port_los'][$index]['level'] & 0x07;
}

function data_pre_long($index){
   global $port_pre_long;
   return (($port_pre_long[$index]['level'] & 0x0f)<<3) | ($port_pre_long[$index]['decay'] & 7);
}

function data_pre_long_decay($index)
{
	return $GLOBALS['port_pre_long'][$index]['decay'] & 0x07;
}
function data_pre_long_level($index)
{
	return $GLOBALS['port_pre_long'][$index]['level'] & 0x0f;
}

function data_pre_short_decay($index)
{
	return $GLOBALS['port_pre_short'][$index]['decay'] & 0x07;
}
function data_pre_short_level($index)
{
	return $GLOBALS['port_pre_short'][$index]['level'] & 0x0f;
}

function data_pre_short($index){
   global $port_pre_short;
   return (($port_pre_short[$index]['level'] & 0x0f)<<3) | ($port_pre_short[$index]['decay'] & 7);
}

function data_out_level($index)
{
	if ($index == -1)
		// return an array of values for each port
		return $GLOBALS['port_out_level'][$index]['level'];
	else
		return $GLOBALS['port_out_level'][$index]['level'] & 0x0f;
}

function data_input_terminate($index)
{
	return $GLOBALS['port_input_state'][$index]['terminate'] & 0x01;
}

function data_input_invert($index)
{
	if ($index == -1)
		// return an array of values for each port
		return $GLOBALS['port_input_state'][$index]['invert'];
	else
		return $GLOBALS['port_input_state'][$index]['invert'] & 0x01;
}

function data_out_state($index)
{
	if ($index == -1)
		// return an array of values for each port
		return $GLOBALS['port_out_state'][$index]['mode'];
	else
		return $GLOBALS['port_out_state'][$index]['mode'] & 0x0f;
}
function data_oob_state($index)
{
	return $GLOBALS['port_out_state'][$index]['oob'] & 0x01;
}




function isIndividualSet($array)
{
	for($i = 0; $i < count($GLOBALS["channels"]); $i++) {
		$port_num = $GLOBALS['channels'][$i][$array['type']];
		if (isset($array[$port_num]))
			return true;
	}
	return false;
}

function isGlobalSet($array)
{
	if (isset($array[-1]))
		return true;
	return false;
}

function getMultiVals($value){
   $aval=explode(':',$value);
   for ($i=0;$i<count($aval);$i++) $aval[$i]+=0;
   return $aval;
}


function programConnections($disableUnused)
{
	global $debug, $channels, $connections, $activeOutputs, $activeInputs; // in init mode all the unused connections will be powered down
	$disable_in = 0x01;
	$disable_conn = 0x10;

	// disable all inputs and reset all connections first
	foreach ($connections as $connection) {
		if ($debug) {
			echo '<!-- connection in[' . $channels[$connection[0]]['in'] . '] -> out[' . $channels[$connection[1]]['out'] . ']-->' . "\n";
			echo '<!-- connection in[' . $channels[$connection[1]]['in'] . '] -> out[' . $channels[$connection[0]]['out'] . ']-->' . "\n";
		}
		// inable inputs
		write_vals($GLOBALS['param_paths']['input_off'] . port_fn($channels[$connection[0]]['in']), 0);
		write_vals($GLOBALS['param_paths']['input_off'] . port_fn($channels[$connection[1]]['in']), 0);
		// set connections
		write_vals($GLOBALS['param_paths']['connections'] . port_fn($channels[$connection[0]]['out']), $channels[$connection[1]]['in']);
		write_vals($GLOBALS['param_paths']['connections'] . port_fn($channels[$connection[1]]['out']), $channels[$connection[0]]['in']);
	}
	// disable unused outputs and inputs
	if ($disableUnused) {
		foreach ($activeOutputs as $port => $value) {
			if (!$value) {
				if ($debug)
					echo '<!-- disabling unused output ' . $port . ' -->' . "\n";
				write_vals($GLOBALS['param_paths']['connections'] . port_fn($port), $disable_conn);
			}
		}
		foreach ($activeInputs as $port => $value) {
			if (!$value) {
				if ($debug)
					echo '<!-- disabling unused input ' . $port . ' -->' . "\n";
				write_vals($GLOBALS['param_paths']['input_off'] . port_fn($port), $disable_in);
			}
		}
	}
}


function listSettings(){
  global $debug,$channels,$connections;
    echo "<h4>Connections</h4>\n<ul>";
  foreach ($connections as $connection) {
    echo '<li>'.$channels[$connection[0]]['name'].' ( '.$channels[$connection[0]]['connector'].' ) <==> '.
                $channels[$connection[1]]['name'].' ( '.$channels[$connection[1]]['connector'].' ):   '."\t".
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
  for ($i=0;$i<count($channels);$i++) if ((strtolower($name)==strtolower($channels[$i]['name'])) || (strtolower($name)==(strtolower($channels[$i]['connector'])))){
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
  for ($i=0;$i<count($channels);$i++) if ((strtolower($name)==strtolower($channels[$i]['name'])) || (strtolower($name)==(strtolower($channels[$i]['connector'])))){
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
  for ($i=0;$i<count($channels);$i++) if ((strtolower($name)==strtolower($channels[$i]['name'])) || (strtolower($name)==(strtolower($channels[$i]['connector'])))){
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
		$name = "all";
	else
		$name = sprintf("port_%02d", $port_num);
	return $name;
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

/** Write a parameter or set of parameters to sysfs file. $vals is an array containing 
 * parameters to set or a single value. If $vals contais more than one parameter then $file_name should be 'all' */
function write_vals($file_name, $vals)
{
	$f = fopen($file_name, 'w');
	if ($f !== false) {
		if (is_array($vals))
			$str = implode(' ', $vals);
		else 
			$str = (string)$vals;
		$num = fwrite($f, $str);
		fclose($f);
	}
}

/** Find port index in the channels list by zero based index given */
function translate_index($index, $dir)
{
	$offset = 8;                  // VSC3304 port numbering starts from 08, the offset is used to minimize legacy code modifications 

	return $GLOBALS['channels'][$index][$dir] - $offset;
}

/** Get maximal port number from the list of all channels. This function is use to check 
 * port number provided by user. */
function max_port_num($dir)
{
	global $channels;
	$max_chn = -1;
	
	foreach ($channels as $chn) {
		if ($chn[$dir] > $max_chn)
			$max_chn = $chn[$dir];
	}
	
	return $max_chn;
}

/** Update channels table in accordance with selected signal path */
function set_channels($port1, $port2, $conn, $port_num, $pcb_conn, &$channels)
{
	// check if the port connection (port1 <-> port2) is valid
	$conn_variant = array();
	$name_variants = array(strtoupper($port1) . '<->' . strtoupper($port2), strtoupper($port2) . '<->' . strtoupper($port1));
	if (array_key_exists($name_variants[0], $conn)) {
		$conn_variant = $conn[$name_variants[0]];
	} elseif (array_key_exists($name_variants[1], $conn)) {
		$conn_variant = $conn[$name_variants[1]];
	}
	
	// update channels table in accordance with the connection mode
	if (!empty($conn_variant)) {
		$pair1 = array($conn_variant[0]['FROM'], $conn_variant[1]['TO']);
		$pair2 = array($conn_variant[1]['FROM'], $conn_variant[0]['TO']);
		foreach ($channels as &$chn) {
			if (empty(array_diff($chn['phy_ports'], $pair1))) {
				$chn['in'] = $port_num[$pcb_conn[$pair1[0]]]['in'];
				$chn['out'] = $port_num[$pcb_conn[$pair1[1]]]['out'];
			} elseif (empty(array_diff($chn['phy_ports'], $pair2))) {
				$chn['in'] = $port_num[$pcb_conn[$pair2[0]]]['in'];
				$chn['out'] = $port_num[$pcb_conn[$pair2[1]]]['out'];
			}
		}
	}
}

/** Convert zero based index to port number */
function index_to_port_num($index)
{
	$offset = 8;                  // VSC3304 port numbering starts from 08, the offset is used to minimize legacy code modifications 
	return $index + $offset;
}

/** Read sysfs and update channels table */
function update_chn_from_sysfs()
{
	$paths = $GLOBALS['param_paths'];
	$out = read_vals($paths['connections'] . 'all');
	for ($index = 0; $index < count($out); $index++) {
		if (($out[$index] & 0x10) == 0) {
			$phy_port_in = pname_from_pnum($out[$index], 'in');
			$phy_port_out = pname_from_pnum(index_to_port_num($index), 'out');
			$pcb_conn_in = array_search($phy_port_in, $GLOBALS['pcb_connections']);
			$pcb_conn_out = array_search($phy_port_out, $GLOBALS['pcb_connections']);
			foreach ($GLOBALS['channels'] as &$chn) {
				if (in_array($pcb_conn_in, $chn['phy_ports'])) {
					$chn['in'] = $out[$index];
				} elseif (in_array($pcb_conn_out, $chn['phy_ports'])) {
					$chn['out'] = index_to_port_num($index);
				}
			}
		}
	}
}

/** Find port name from its corresponding number and direction */
function pname_from_pnum($port_num, $port_dir)
{
	foreach ($GLOBALS['port_num'] as $phy_name => $pair) {
		if ($pair[$port_dir] == $port_num)
			return $phy_name;
	}
	return '';
}

function apply_defaults($param_dir, $data)
{
	if (is_array($data)) {
		for ($index = 0; $index < count($data); $index++) {
			$fname = $param_dir . port_fn(index_to_port_num($index));
			if (file_exists($fname)) {
				write_vals($fname, $data[$index]);
			}
		}
	} else {
		write_vals($param_dir . 'all', $data);
	}
}

?> 
