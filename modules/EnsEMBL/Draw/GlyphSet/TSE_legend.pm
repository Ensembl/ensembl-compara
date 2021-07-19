=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::TSE_legend;

### Legend for Transcript/SupportingEvidence

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _icon_exonintron {
  my ($self,$x,$y,$k) = @_;

  $self->push($self->Rect({
    x             => $x,
    y             => $y,
    width         => $self->{'box_width'},
    height        => $self->{'text_height'},
    colour        => $k->{'colour'},
    absolutey     => 1, absolutex => 1, absolutewidth => 1,
  }));
  $self->push($self->Line({
    x             => $x + $self->{'box_width'},
    y             => $y + $self->{'text_height'}/2,
    h             => 1,
    width         => $self->{'box_width'},
    colour        => $k->{'colour'},
    absolutey     => 1, absolutex => 1, absolutewidth => 1,
  }));

  return ($self->{'box_width'}*2,$self->{'text_height'});
}

sub _icon_intron {
  my ($self,$x,$y,$k) = @_;

  $self->push($self->Rect({
    x             => $x,
    y             => $y,
    width         => $self->{'box_width'},
    height        => $self->{'text_height'},
    colour        => $k->{'colour'},
    absolutey     => 1, absolutex => 1, absolutewidth => 1,
  }));
  return ($self->{'box_width'}*2,$self->{'text_height'});
}

sub _icon_exonintronexon {
  my ($self,$x,$y,$k) = @_;

  my $h = int($self->{'text_height'} * 0.8);
  foreach my $box (0,2) {
    $self->push($self->Rect({
      x => $x + $box*$self->{'box_width'},
      y => $y,
      width => $self->{'box_width'},
      height => $h,
      bordercolour => 'black',
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
    }));
  }
  $self->push($self->Line({
    x => $x + $self->{'box_width'},
    y => $y + $h/2,
    width => $self->{'box_width'},
    height => 0,
    absolutey     => 1, absolutex => 1, absolutewidth => 1,
    colour => $k->{'colour'},
    dotted => 1,
  }));
  
  return ($self->{'box_width'}*3,$h);
}

sub _icon_beyond {
  my ($self,$x,$y,$k) = @_;

  my $d = 8; # tick height
  my $h = int($self->{'text_height'} * 0.8);
  foreach my $box (0,1) {
    $self->push($self->Rect({
      x => $x + ($box?0:$self->{'box_width'}*2),
      y => $y + $box*($h+2),
      width => $self->{'box_width'},
      height => $h,
      bordercolour => 'black',
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
    }));
    $self->push($self->Line({
      x => $x + $box*$self->{'box_width'},
      y => $y + $box*($h+2) + $h/2,
      width => $self->{'box_width'}*2,
      height => 0,
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
      dotted => 1,
      colour => $k->{'colour'},
    }));
    $self->push($self->Line({
      x => $x + $box*$self->{'box_width'}*3,
      y => $y + $box*($h+2) + $h/2 - $d/2,
      width => 0,
      height => $d,
      colour => $k->{'colour'},
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
    }));
  }
  return ($self->{'box_width'}*3,$h*2+2);
}

sub _icon_noncanon {
  my ($self,$x,$y,$k) = @_;

  my $d = 6; # hight of the ticks
  $self->push($self->Line({
    x             => $x,
    y             => $y + $self->{'text_height'}/2,
    width         => $self->{'box_width'},
    height        => 0,
    colour        => $k->{'colour'},
    absolutey     => 1, absolutex => 1, absolutewidth => 1,
  }));
  foreach my $xo (0,$self->{'box_width'}) {
    $self->push($self->Line({
      x => $x + $xo,
      y => $y + $self->{'text_height'}/2 - $d/2,
      width => 0,
      height => $d,
      colour => $k->{'colour'},
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
    }));
  } 
  return ($self->{'box_width'},$self->{'text_height'});
}

sub _icon_ends {
  my ($self,$x,$y,$k) = @_; 

  my $w = 3; # thick end width
  my $h = int($self->{'text_height'} * 0.8);
  foreach my $box (0,1) {
    $self->push($self->Rect({
      x             => $x,
      y             => $y + $box*($h+2),
      width         => $self->{'box_width'},
      height        => $h,
      bordercolour  => 'black',
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
    }));
    $self->push($self->Rect({
      x             => $x + $box*($self->{'box_width'}-$w),
      y             => $y + $box*($h+2),
      width         => $w,
      height        => $h,
      colour        => $k->{'colour'},
      absolutey     => 1, absolutex => 1, absolutewidth => 1,
    }));
  }
  return ($self->{'box_width'},$h*2+2);
}

sub _init {
  my ($self) = @_;
  my $wuc           = $self->{'config'};
  my $o_type        = $wuc->cache('trans_object')->{'object_type'};

  $self->init_legend(4);

  my (@left_group,@right_group);

  # evidence types
  my %features = $wuc->cache('legend') ? %{$wuc->cache('legend')} : ();
  foreach my $f (sort { $features{$a}->{'priority'} <=> $features{$b}->{'priority'} } keys %features) {
    my $e_type = $f;
    $e_type =~ s/cdna/cDNA/;
    $e_type =~ s/est/EST/;

    my $legend = ($e_type eq 'evidence_removed') ? 'Evidence removed' : "$e_type evidence";
    my $style = $features{$f}->{'style'} || 'exonintron';
    $self->add_to_legend({
      legend => $legend,
      colour => $features{$f}->{'colour'},
      style => $style,
    });
  }
	
  $self->init_legend(2);
  $self->newline();

  # non-canonical 
  push @left_group,{
    legend => 'non-canonical splice site',
    colour => $self->my_colour('non_can_intron'),
    style => 'noncanon'
  };

  # evidence extent
  unless($o_type =~ /otter/) {
    push @left_group,{
      legend => 'evidence start / ends within exon / CDS',
      colour => $self->my_colour('evi_short'),
      style => 'ends',
    },{
      legend => 'evidence extends beyond exon / CDS',
      colour => $self->my_colour('evi_long'),
      style => 'ends',
    };
  }

  # evidence missing / duplicated
  unless ($o_type =~ /otter/) {
    push @right_group,{
      legend => 'part of evidence duplicated in transcript structure',
      colour => $self->my_colour('evi_extra'),
      style => 'exonintronexon',
    };
  }
  push @right_group,{
    legend => 'part of evidence missing from transcript structure',
    colour => $self->my_colour('evi_missing'),
    style => 'exonintronexon',
  };
 
  #lines extending beyond the end of the hit
  if( $o_type !~ /otter/ ) {
    push @right_group,{
      legend => 'evidence extends beyond the end of the transcript',
      colour => $self->my_colour('evi_long'),
      style => 'beyond',
    };
  }
  $self->add_vgroup_to_legend(\@left_group);
  $self->add_vgroup_to_legend(\@right_group);
}

1;
