package EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl;

use strict;
use warnings;

use base qw(EnsEMBL::Web::QueryStore::Cache);

use JSON;
use Fcntl qw(SEEK_SET SEEK_END :flock);
use Sys::Hostname;
use DB_File;
use File::Copy;
use Compress::Zlib;

use bytes;

sub new {
  my ($proto,$conf) = @_;

  my $class = ref($proto) || $proto;

  my $rnd = EnsEMBL::Web::QueryStore::Cache->_key({ pid => $$, now => localtime, host => hostname });
  my $widxfile = $conf->{'dir'}."/$rnd.raw";
  my $wdatfile = $conf->{'dir'}."/$rnd.dat";
  my $ridxfile = $conf->{'dir'}."/boe.idx";
  my $rdatfile = $conf->{'dir'}."/boe.dat";
  my $lockfile = $conf->{'dir'}."/boe.lok";

  my $self = {
    dir => $conf->{'dir'},
    wdatfile => $wdatfile,
    widxfile => $widxfile,
    ridxfile => $ridxfile,
    rdatfile => $rdatfile,
    lockfile => $lockfile,
    any => 0,
  };
  bless $self,$class;
  return $self;
}

sub cache_open {
  my ($self) = @_;

  my %widx;
  tie %widx,'DB_File',$self->{'widxfile'},O_CREAT|O_RDWR,0600,$DB_HASH
    or die "Cannot write $self->{'widxfile'}";
  $self->{'widx'} = \%widx;
  open($self->{'wdat'},'>:raw',$self->{'wdatfile'}) or die "Cannot write";
  my %ridx;
  tie %ridx,'DB_File',$self->{'ridxfile'},O_CREAT|O_RDONLY,0600,$DB_HASH
    or die "Cannot read $self->{'ridxfile'}";
  $self->{'ridx'} = \%ridx;
  unless(-e $self->{'rdatfile'}) {
    open(TMP,">>",$self->{'rdatfile'});
    close TMP; 
  }
  open($self->{'rdat'},'<:raw',$self->{'rdatfile'}) or die "Cannot read";
}

sub set {
  my ($self,$args,$v) = @_;

  my $key = $self->_key($args);
  my $value = Compress::Zlib::memGzip(JSON->new->encode($v));
  $self->{'any'} = 1;
  my $start = tell $self->{'wdat'};
  $self->{'wdat'}->print($value);
  my $end = tell $self->{'wdat'};
  $self->{'widx'}{$key} = JSON->new->encode([$start,$end-$start]);
}

sub get {
  my ($self,$k) = @_;

  my $json = $self->{'ridx'}{$self->_key($k)};
  return undef unless $json;
  my $d = JSON->new->decode($json);
  seek $self->{'rdat'},$d->[0],SEEK_SET;
  my $out;
  read($self->{'rdat'},$out,$d->[1]);
  return JSON->new->decode(Compress::Zlib::memGunzip($out));
}

sub _consolidate {
  my ($self) = @_;

  open(LOCK,">>",$self->{'lockfile'}) or die;
  flock(LOCK,LOCK_EX) or die;
  (my $newidx = $self->{'ridxfile'}) =~ s/$/.tmp/;
  (my $newdat = $self->{'rdatfile'}) =~ s/$/.tmp/;
  copy($self->{'ridxfile'},$newidx) or die;
  copy($self->{'rdatfile'},$newdat) or die;
  tie(my %out,'DB_File',$newidx,O_RDWR) or die;
  open(OUTDAT,">>:raw",$newdat) or die;
  opendir(DIR,$self->{'dir'}) or die;
  foreach my $f (readdir(DIR)) {
    next unless $f =~ /\.ready$/;
    my $idx = "$self->{'dir'}/$f";
    (my $dat = $f) =~ s/ready$/dat/;
    $dat = "$self->{'dir'}/$dat";
    tie(my %in,'DB_File',$idx,O_RDONLY) or die;
    open(INDAT,$dat) or die;
    while(my ($k,$v) = each %in) {
      next if $out{$k};
      my $d = JSON->new->decode($v);
      my $data;
      seek INDAT,$d->[0],SEEK_SET or die;
      read INDAT,$data,$d->[1];
      seek OUTDAT,0,SEEK_END;
      my $start = tell OUTDAT;
      print OUTDAT $data;
      my $end = tell OUTDAT;
      $out{$k} = JSON->new->encode([$start,$end-$start]); 
    }
    close INDAT;
    untie %in;
    unlink $idx;
    unlink $dat;
  }
  closedir DIR;  
  close OUTDAT;
  untie %out;
  rename($newdat,$self->{'rdatfile'});
  rename($newidx,$self->{'ridxfile'});
  flock(LOCK,LOCK_UN);
  close(LOCK); 
}

sub cache_close {
  my ($self) = @_;

  close $self->{'wdat'};
  untie %{$self->{'widx'}};
  if($self->{'any'}) {
    (my $ready = $self->{'widxfile'}) =~ s/\.raw$/\.ready/;
    rename $self->{'widxfile'},$ready;
    $self->_consolidate;
  } else {
    unlink $self->{'widxfile'};
    unlink $self->{'wdatfile'};
  }
}

1;
