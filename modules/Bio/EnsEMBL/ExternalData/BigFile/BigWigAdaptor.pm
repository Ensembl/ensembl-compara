package Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;
use strict;

use Data::Dumper;
use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;
my $DEBUG = 0;


sub new {
  my ($class, $url) = @_;

  my $self = bless {
    _cache => {},
    _url => $url,
  }, $class;
      
  return $self;
}

sub url { return $_[0]->{'_url'} };

sub bigwig_open {
  my $self = shift;

  Bio::DB::BigFile->set_udc_defaults;
  $self->{_cache}->{_bigwig_handle} ||= Bio::DB::BigFile->bigWigFileOpen($self->url);
  return $self->{_cache}->{_bigwig_handle};
}


# UCSC prepend 'chr' on human chr ids. These are in some of the BigWig
# files. This method returns a possibly modified chr_id after
# checking whats in the BigWig file
sub munge_chr_id {
  my ($self, $chr_id) = @_;

  my $ret_id;

  my $bw = $self->bigwig_open;
  warn "Failed to open BigWig file " . $self->url unless $bw;
  return undef unless $bw;

  my $ret_id = $chr_id;

  # Check we get values back for seq region. Maybe need to add 'chr' 
  my $length = $bw->chromSize("$chr_id");

  if (!$length) {
    $length = $bw->chromSize("chr$chr_id");
    if ($length) {
      $ret_id = "chr$chr_id";
    } else {
      warn " *** could not find region $chr_id in BigWig file\n";
      return undef;
    }
  }

  return $ret_id;
}

sub fetch_extended_summary_array {
  my ($self, $chr_id, $start, $end, $bins) = @_;

  my $bw = $self->bigwig_open;
  warn "Failed to open BigWig file" . $self->url unless $bw;
  return [] unless $bw;
  
  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $summary_e = $bw->bigWigSummaryArrayExtended("$seq_id",$start-1,$end,$bins);

  if ($DEBUG) {
    warn " *** fetch extended summary: $chr_id:$start-$end : found ", scalar(@$summary_e), " summary points\n";
  }
  
  return $summary_e;
}

1;
