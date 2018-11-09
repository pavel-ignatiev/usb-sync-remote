<?php

// Debug options
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Socket file to get data from client
$client_socket = "/tmp/client_socket.ini";

// Get file contents
$client_msg = parse_ini_file("$client_socket", FALSE, INI_SCANNER_TYPED);

// Server data path
$source_path = "/var/www/html/data/";

// Server data directory size in bytes
$data_amount = intval(shell_exec("du -shk $source_path | cut -f1"));

// Server data transfer trigger
$data_ready = 'yes';

// Server html output path
$html_output = "/var/www/html/service/index.html";
file_put_contents($html_output, $client_msg);
chmod($html_output, 0664);

// Parse HTTP query from client and respond
if ( ( isset ($_SERVER['QUERY_STRING']) ) and ( ! empty ($_SERVER['QUERY_STRING']) ) ) {

	$query = $_SERVER['QUERY_STRING'];

	switch ($query) {
		case "data_ready":
			echo "$data_ready";
			break;
		case "data_amount":
			echo "$data_amount";
			break;
		case "source_path":
			echo "$source_path";
			break;
		default:
			die();
	}

}

die();
