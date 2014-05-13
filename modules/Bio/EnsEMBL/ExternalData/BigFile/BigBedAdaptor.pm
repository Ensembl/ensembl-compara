=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;
use strict;

use List::Util qw(max);

use Data::Dumper;
use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;

use EnsEMBL::Web::Text::Feature::BED;

# Standard BED columns and where to find them: this will need adding to
#   when we come across various whacky field names.
my @bed_columns = (
  ['chrom',0],
  ['chromStart',1],
  ['chromEnd',2],
  ['name'],
  ['score'],
  ['strand'],
);

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

sub _parse_as {
  my ($self,$in) = @_;

  my %out;
  while($in) {
    next unless $in->isTable;
    my @table;
    my $cols = $in->columnList;
    while($cols) {
      push @table,[$cols->lowType->name,$cols->name,$cols->comment];
      $cols = $cols->next;
    }
    $out{$in->name} = \@table;
    $in = $in->next;
  }
  return \%out;
}

sub autosql {
  my $self = shift;

  unless($self->{'_cache'}->{'_as'}) {
    my $bb = $self->bigbed_open;
    my $as = $self->_parse_as($bb->bigBedAs);
    $self->{'_cache'}->{'_as'} = $as;
  }
  return $self->{'_cache'}->{'_as'};
}

# UCSC prepend 'chr' on human chr ids. These are in some of the BigBed
# files. This method returns a possibly modified chr_id after
# checking whats in the BigBed file
sub munge_chr_id {
  my ($self, $chr_id) = @_;
  my $bb = $self->bigbed_open;
  
  warn "Failed to open BigBed file " . $self->url unless $bb;
  
  return undef unless $bb;

  my $list = $bb->chromList;
  my $head = $list->head;
  my $ret_id;
  
  do {
    $ret_id = $head->name if $head->name =~ /^(chr)?$chr_id$/ && $head->size; # Check we get values back for seq region. Maybe need to add 'chr' 
  } while (!$ret_id && ($head = $head->next));
  
  warn " *** could not find region $chr_id in BigBed file" unless $ret_id;
  
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

sub _as_mapping {
  my ($self) = @_;

  my $as = $self->autosql;
  return undef unless $as;
  my (%map,%core,@order,%pos);
  my $table = $as->{[keys %$as]->[0]};
  foreach my $idx_bed (0..$#bed_columns) {
    foreach my $try (@{$bed_columns[$idx_bed]}) {
      foreach my $idx_file (0..$#$table) {
        my $colname = $table->[$idx_file][1];
        if($try eq $colname or $colname =~ /^(\d+)$/ && $idx_file == $1) {
          $map{$idx_bed} ||= $idx_file;
          $core{$colname} = 1;
          last;
        }
      }
      last if defined $map{$idx_bed};
    }
  }
  foreach my $idx_file (0..$#$table) {
    my $colname = $table->[$idx_file][1];
    $pos{$colname} = $idx_file;
    next if $core{$colname};
    push @order,$colname;
  }
  return [\%map,\%pos,\@order];
}

sub _as_transform {
  my ($self,$data) = @_;

  unless(exists $self->{'_bigbed_as_mapping'}) {
    $self->{'_bigbed_as_mapping'} = $self->_as_mapping;
  }
  my ($map,$pos,$order) = @{$self->{'_bigbed_as_mapping'}};

  my (@out,%extra);
  foreach my $i (0..$#bed_columns) {
    $out[$map->{$i}] = $data->[$i] || undef;
  }
  foreach my $name (@$order) {
    $extra{$name} = $data->[$pos->{$name}];
  }
  return (\@out,\%extra,$order);
}

sub fetch_features  {
  my ($self, $chr_id, $start, $end) = @_;

  my @features;
  $self->fetch_rows($chr_id,$start,$end,sub {
    my ($row,$extra,$order) = $self->_as_transform(\@_);
    my $bed = EnsEMBL::Web::Text::Feature::BED->new($row,$extra,$order);
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
