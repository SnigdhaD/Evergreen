#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright (C) 2012 Equinox Software, Inc
# Author: Bill Erickson <berick@esilibrary.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------
use strict; 
use warnings;
use DateTime;
use Getopt::Long;
use OpenSRF::System;
use OpenSRF::AppSession;
use OpenILS::Utils::CStoreEditor;
use OpenILS::Utils::RemoteAccount;
use OpenILS::Utils::Fieldmapper;

my $osrf_config = '/openils/conf/opensrf_core.xml';
my $start_date  = DateTime->now->strftime('%F');
my $end_date    = '';
my $event_defs  = '';
my $granularity = '';
my $output_file = '';
my $local_dir   = '/tmp'; # where to keep local copies of generated files
my $remote_acct = '';
my $cleanup     = 0; # cleanup generated files
my $verbose     = 0;
my $help        = 0;

GetOptions(
    'osrf-config=s'     => \$osrf_config,
    'start-date=s'      => \$start_date,
    'end-date=s'        => \$end_date,
    'event-defs=s'      => \$event_defs,
    'granularity=s'     => \$granularity,
    'output-file=s'     => \$output_file,
    'remote-acct=s'     => \$remote_acct,
    'local-dir=s'       => \$local_dir,
    'cleanup'           => \$cleanup,
    'verbose'           => \$verbose,
    'help'              => \$help
);

sub help {
    print <<HELP;

Action/Trigger Aggregator Script

Collect template output from one or more event-definitions and stitch the 
results together in a single file.  The file may be optionally stored locally
and/or delivered to a remote ftp/scp account.

This script is useful for generating a single mass notification (e.g. overdue)
file and sending the file to a 3rd party for processing and/or for local 
processing.  The anticipated use case would be to stitch together lines of CSV 
or chunks of XML.

Example

# Collect a week of notifications for 3 event definitions

$0 \
    --event-defs 104,105,106 \
    --start-date 2012-01-01 \
    --end-date 2012-01-07 \
    --output-file 2012-01-07.notify.csv \
    --local-dir /var/run/evergreen/csv \
    --remote-account 6

Options

    --event-defs 
        action_trigger.event_definition IDs to include

    --granularity
        Process all event definitions that match this granularity.  If used in
        conjunction with --event-defs, the union of the two sets is used.
    
    --start-date 
        Only collect output for events whose run_time is on or after this ISO date

    --end-date 
        Only collect output for events whose run_time occurred before this IDO date

    --output-file [default STDOUT]
        Output goes to this file.  

    --local-dir [default /tmp]
        Local directory where the output-file is placed.  If --cleanup is 
        set, this is used as the tmp directory for file generation

    --remote-account
        Evergreen config.remote_account ID
        If set, the output-file will be sent via sFTP/SCP to this server.

HELP
    exit;
}

help() if $help;

my @event_defs = split(/,/, $event_defs);
die "--event-defs or --granularity required\n" 
    unless @event_defs or $granularity;

my $local_file = $output_file ? "$local_dir/$output_file" : '&STDOUT';

open(OUTFILE, ">$local_file") or 
    die "unable to open out-file '$local_file' for writing: $!\n";
binmode(OUTFILE, ":utf8");

print "Output will be written to $local_file\n" if $verbose;

OpenSRF::System->bootstrap_client(config_file => $osrf_config);
Fieldmapper->import(IDL => 
    OpenSRF::Utils::SettingsClient->new->config_value("IDL"));
OpenILS::Utils::CStoreEditor::init();
my $editor = OpenILS::Utils::CStoreEditor->new;

# if granularity is set, append all event defs with the 
# selected granularity to the set of event-defs to process.
if ($granularity) {
    my $defs = $editor->search_action_trigger_event_definition(
        {granularity => $granularity},
        {idlist => 1}
    );

    for my $id (@$defs) {
        push(@event_defs, $id) 
            unless grep { $_ eq $id} @event_defs;
    }
}

print "Processing event-defs @event_defs\n" if $verbose;

my %date_filter;
$date_filter{run_time} = {'>=' => $start_date} if $start_date;
$date_filter{run_time} = {'<' => $end_date} if $end_date;

# collect the event tempate output data
# use a real session here so we can stream results directly to the output file
my $ses = OpenSRF::AppSession->create('open-ils.cstore');
my $req = $ses->request(
    'open-ils.cstore.json_query', {
        select => {ateo => ['data']},
        from => {ateo => { atev => {
            filter => {state => 'complete', %date_filter},
            join => {atevdef => {filter => {
                id => \@event_defs,
                active => 't'
            }}}
        }}}
    }
);

# use a large timeout since this is likely to be a hefty query
while (my $resp = $req->recv(timeout => 3600)) {
    die $req->failed . "\n" if $req->failed;
    my $content = $resp->content or next;
    print OUTFILE $content->{data};
}

if ($remote_acct) {
    # send the file to the remote account

    my $racct = $editor->retrieve_config_remote_account($remote_acct);
    die "No such remote account $remote_acct" unless $racct;

    my $type;
    my $host = $racct->host;
    ($host =~ s/^(S?FTP)://i and $type = uc($1)) or                   
    ($host =~ s/^(SSH|SCP)://i and $type = 'SCP');
    $host =~ s#//##;

    my $acct = OpenILS::Utils::RemoteAccount->new(
        type            => $type,
        remote_host     => $host,
        account_object  => $racct,
        local_file      => $local_file,
        remote_file     => $output_file
    );

    my $res = $acct->put;

    die "Unable to push to remote server [$remote_acct] : " . 
        $acct->error . "\n" unless $res;

    print "Pushed file to $res\n" if $verbose;
}

if ($cleanup) {
    unlink($local_file) or 
        die "Unable to clean up file '$local_file' : $!\n";
}


