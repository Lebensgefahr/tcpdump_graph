#!/usr/bin/perl

use strict;
#use warnings;
use Data::Dumper;

my $cont_list = $ARGV[0];
my $dump = $ARGV[1];
my $file = $ARGV[2];

our (@dst, @src, %con, %containers, %sock, $clusters, $connections);
our $cluster_num = 0;
my %random_ports = map {$_ => 1} (32768..60990);

if (-e $cont_list) {
  open (FH, $cont_list);
  while (my $str = <FH>) {
    chomp $str;
    my ($name, $ips) = split(':', $str);
    my (@ip) = split(',', $ips);
    for my $ip (@ip) {
      $containers{$ip} = $name;
#      print ("$ip"."\n");
#print Dumper \%containers;
    }
  }
}

close(FH);

open (FH, $dump) or die "Could not open file '$dump' $!";
while (my $str = <FH>) {
  chomp $str;
#  if($str =~ m/^IP\s(\d{1,3}(?:\.\d{1,3}){3})\.(\d{1,5})\s>\s(\d{1,3}(?:\.\d{1,3}){3})\.(\d{1,5}):\s(?!UDP)/){
  if($str =~ m/.*IP\s(\d{1,3}(?:\.\d{1,3}){3})\.(\d{1,5})\s>\s(\d{1,3}(?:\.\d{1,3}){3})\.(\d{1,5}):\s(?!UDP)/){
#    print ($1." ".$2." ".$3." ".$4."\n");
    my ($src_ip, $src_port, $dst_ip, $dst_port) = ($1, $2, $3, $4);
    if (exists $random_ports{$src_port}) {
      $src_port = "random";
    }
    if (exists $random_ports{$dst_port}) {
      $dst_port = "random";
    }

    $sock{$src_ip}{$src_port}="";
    $sock{$dst_ip}{$dst_port}="";

    if(exists $con{$src_ip}{$src_port}{$dst_ip}{$dst_port}) {
      $con{$src_ip}{$src_port}{$dst_ip}{$dst_port}++;
    } else {
      $con{$src_ip}{$src_port}{$dst_ip}{$dst_port} = 1;
    }

  }
}
close(FH);
#print Dumper \%con;
#print Dumper \%sock;
#print Dumper \%containers;

$clusters .= "digraph {";
addSubgraph();
for my $src_ip (keys %con){
  for my $src_port (keys %{$con{$src_ip}}){
    for my $dst_ip (keys %{$con{$src_ip}{$src_port}}){
      for my $dst_port (keys %{$con{$src_ip}{$src_port}{$dst_ip}}){
        addCon($src_ip, $src_port, $dst_ip, $dst_port);
      }
    }
  }
}
$connections .= "}";

open (FH, '>', $file) or die "Could not open file '$file' $!";
print (FH $clusters);
print (FH $connections);
close(FH);

sub addSubgraph {
  my $label;
  for my $ip (keys %sock) {
    if(exists $containers{$ip}){
      $label = $containers{$ip}."(".$ip.")";
    } else {
      $label = $ip;
    }
  $clusters .= "
  subgraph cluster_".$cluster_num++." {
    style=rounded;
    bgcolor=\"gray\";
    color=lightgrey;
    node [style=filled,color=white ];
    label = \"$label\";\n";
    for my $port (keys %{$sock{$ip}}) {
      $clusters .= "    \"$ip:$port\" [label=\"$port\" fontsize=\"8\"];\n";
    }
  $clusters .= "  }\n";
  }

}

sub addCon {
  my ($src_ip, $src_port, $dst_ip, $dst_port) = @_;
  if (exists $con{$dst_ip}{$dst_port}{$src_ip}{$src_port}) {
    my $packets_count = $con{$src_ip}{$src_port}{$dst_ip}{$dst_port} + $con{$dst_ip}{$dst_port}{$src_ip}{$src_port};
    $connections .= "  \"$src_ip:$src_port\" -> \"$dst_ip:$dst_port\" [fontsize=6 label = \"".$packets_count."\" dir=\"both\"];\n";
    delete($con{$dst_ip}{$dst_port}{$src_ip}{$src_port});
  } elsif ($src_port eq "random") {
    $connections .= "  \"$src_ip:$src_port\" -> \"$dst_ip:$dst_port\" [fontsize=6 label=\"".$con{$src_ip}{$src_port}{$dst_ip}{$dst_port}."\"dir=\"front\"];\n";
  } else {
    $connections .= "  \"$src_ip:$src_port\" -> \"$dst_ip:$dst_port\"[fontsize=6 label=\"".$con{$src_ip}{$src_port}{$dst_ip}{$dst_port}."\"];\n";
  }
}