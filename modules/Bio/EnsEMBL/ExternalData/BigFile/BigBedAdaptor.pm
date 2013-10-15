package Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;
use strict;

use List::Util qw(max);

use Data::Dumper;
use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;

use EnsEMBL::Web::Text::Feature::BED;

sub new {
  my ($class, $url) = @_;

  my $self = bless {
    _cache => {},
    _url => $url,
  }, $class;
      
  return $self;
}

sub url { return $_[0]->{'_url'} };

sub bigbed_open {
  my $self = shift;

  Bio::DB::BigFile->set_udc_defaults;
  $self->{_cache}->{_bigbed_handle} ||= Bio::DB::BigFile->bigBedFileOpen($self->url);
  return $self->{_cache}->{_bigbed_handle};
}


# UCSC prepend 'chr' on human chr ids. These are in some of the BigBed
# files. This method returns a possibly modified chr_id after
# checking whats in the BigBed file
sub munge_chr_id {
  my ($self, $chr_id) = @_;

  my $ret_id;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file " . $self->url unless $bb;
  return undef unless $bb;

  my $ret_id = $chr_id;

  # Check we get values back for seq region. Maybe need to add 'chr' 
  my $length = $bb->chromSize("$chr_id");

  if (!$length) {
    $length = $bb->chromSize("chr$chr_id");
    if ($length) {
      $ret_id = "chr$chr_id";
    } else {
      warn " *** could not find region $chr_id in BigBed file\n";
      return undef;
    }
  }

  return $ret_id;
}

sub fetch_extended_summary_array  {
  my ($self, $chr_id, $start, $end, $bins) = @_;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file" . $self->url unless $bb;
  return [] unless $bb;
  
  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $summary_e = $bb->bigBedSummaryArrayExtended("$seq_id",$start-1,$end,$bins);

  return $summary_e;
}

sub fetch_features  {
  my ($self, $chr_id, $start, $end) = @_;

  my @features;
  $self->fetch_rows($chr_id,$start,$end,sub {
    my $bed = EnsEMBL::Web::Text::Feature::BED->new(\@_);
    $bed->coords([$_[0],$_[1],$_[2]]);

    ## Set score to undef if missing to distinguish it from a genuine present but zero score
    $bed->score(undef) if @_ < 5;

    $self->{_cache}->{numfield} = max($self->{_cache}->{numfield}, scalar(@_)); 

    push @features,$bed;
  });
  return \@features;
}

sub fetch_rows  {
  my ($self, $chr_id, $start, $end, $dowhat) = @_;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file" . $self->url unless $bb;
  return [] unless $bb;
  
  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $list_head = $bb->bigBedIntervalQuery("$seq_id",$start-1,$end-1);

  for (my $i=$list_head->head;$i;$i=$i->next) {
    my @bedline = ($chr_id,$i->start,$i->end,split(/\t/,$i->rest));
    &{$dowhat}(@bedline);
  }
}

sub file_bedline_length {
  my $self = shift;
  my $length = 3;
  my $num = 0;

  # If already fetched some features using this adaptor then use cached max number of fields
  if (exists($self->{_cache}->{numfield})) {
    return $self->{_cache}->{numfield};
  }

  # Else sample the file - this is rather inefficient
  my $MAX_SAMPLE_SIZE = 100;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file" . $self->url unless $bb;
  # list needs to exist and not be undefed until done to avoid SIGSEG
  my $list = $bb->chromList;
  SAMPLE: for (my $c = $list->head; $c; $c=$c->next) {
    my $intervals = $bb->bigBedIntervalQuery($c->name,0,$c->size,$MAX_SAMPLE_SIZE);
    for (my $i=$intervals->head;$i;$i=$i->next) {
      $length = max($length,3 + scalar split(/\t/,$i->rest));
      $num++;
      last SAMPLE if $num > $MAX_SAMPLE_SIZE;
    }
  }
  return $length;
}

1;
