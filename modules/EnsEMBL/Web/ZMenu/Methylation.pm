=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Methylation;

use strict;

use List::Util qw(min max);
use URI::Escape qw(uri_unescape);

use Bio::EnsEMBL::IO::Parser;

use base qw(EnsEMBL::Web::ZMenu);

sub summary_zmenu {
  my ($self, $args) = @_;

  my ($fudge, $slice, $rs, $ch3fa, $bba) = $self->_menu_setup($args); 

  my $r   = $args->{'r'};
  my $s   = $args->{'start'};
  my $e   = $args->{'end'};
 
  # Round fudge to 1sf
  my $mult = "1"."0"x(length(int $fudge)-1);
  $fudge = int(($fudge/$mult)+0.5)*$mult;  
  my $mid = ($s+$e)/2;
  $s = int($mid - $fudge/2);
  $e = int($mid + $fudge/2);
  
  # Summarize features
  my ($num,$num_this_strand,$tot_meth,$tot_read) = (0,0,0,0);
  my ($label,@percmeth,@rows);
  my $maxmult = 2; # show multiple zmenus if this many results or fewer
  $bba->fetch_rows($slice->seq_region_name,$s,$e+1,sub {
    my @row = @_;
    my $f = Bio::EnsEMBL::Funcgen::DNAMethylationFeature->new( 
          -SLICE => $slice, 
            -SET => $rs, 
      -FILE_DATA => \@row, 
        -ADAPTOR => $ch3fa
    );
    my $p = $f->percent_methylation;
    push @percmeth,$p;
    $tot_meth += $f->methylated_reads;
    $tot_read += $f->total_reads;    
    $label = $f->display_label;
    my $right_strand = ($args->{'strand'} == $_[5]."1");
    my ($tstart,$tstrand) = ($_[1]+1,$_[5]."1");
    push @rows,[$tstart,$tstrand] if @rows < $maxmult;
    $num++;
    $num_this_strand++ if($right_strand);
  });
  @percmeth = sort { $a <=> $b } @percmeth;
  
  if($num==0) {
    # No features
    $self->caption("$label No features within ${fudge}bp");
    $self->add_entry({  type => "Overview",
                       label => "This track has no features near this point"});
    # 1. never do this if called from single (avoid infinite loop);
    # 2. if only one on this strand show single for this strand;
    # 3. if there's only a few and we're zoomed out, show stacked.
  } elsif ((($num<=$maxmult and $args->{'scalex'} < 8) 
            or $num_this_strand==1) 
          and not $args->{'called_from_single'}) {
    # Multiple singles
    foreach (@rows) {
      my %params        = %$args;
      $params{'start'}  = $_->[0];
      $params{'end'}    = $_->[1];
      $self->single_base_zmenu(\%params);
    }
  } else {
    # Multiple features
    $self->caption("$label ${fudge}bp summary");
    my ($chr,) = split(/:/,$r);

    $self->add_entry({ type => "Region Summary",
                       label => "Zoom using link below for individual feature details" });
    $self->add_entry({ type => "Location",
                       label => "$chr:$s-$e"});
    $self->add_entry({ type => "Feature Count",
                       label => $num });
    $self->add_entry({ type => "Methylated Reads",
                       label => sprintf("%d/%d",$tot_meth,$tot_read) });
    $self->add_entry({ type => "Min/Median/Max Methylation",
                       label => sprintf("%d%%/%d%%/%d%%",
                                        $percmeth[0],
                                        $percmeth[int($#percmeth/2)],
                                        $percmeth[$#percmeth]) });
  }
}

sub single_base_zmenu {
  my ($self, $args) = @_;

  my ($fudge, $slice, $rs, $ch3fa, $bba) = $self->_menu_setup($args); 
    
  my $r   = $args->{'r'};
  my $s   = $args->{'start'};
  my $e   = $args->{'end'};
 
  # Find nearest feature
  my @bigbedrow;
  my $closest = -1;
  $bba->fetch_rows($slice->seq_region_name, $s-$fudge, $s+1+$fudge, sub {
    my $dist = abs($_[1]+1-$s) + 0.5 * ($args->{'strand'} != $_[5]."1");
    if($closest == -1 or $dist < $closest) {
      @bigbedrow = @_;
      $closest = $dist;
    }
  });
  unless(@bigbedrow) {
    # user must have clicked on blank area
    $args->{'called_from_single'} = 1;
    $self->summary_zmenu($args);
    return;
  }
  my $s = $bigbedrow[1]+1;
  my $e = $s+1;

  #warn "got ".join(' ',@bigbedrow)."\n";
  my $f = Bio::EnsEMBL::Funcgen::DNAMethylationFeature->new( 
        -SLICE => $slice, 
          -SET => $rs, 
    -FILE_DATA => \@bigbedrow, 
      -ADAPTOR => $ch3fa
  );
  
  my ($chr,) = split(/:/,$r);
  if($self->{'_sent_caption'}) {
    $self->add_subheader($f->display_label." $chr:$s");
    $self->add_entry({ type => "Location", label => "$chr:$s" });
  } else {
    $self->caption($f->display_label." $chr:$s");
    $self->add_entry({ type => "Location", label => "$chr:$s" });
    $self->add_entry({ type => "Context", label => $f->context}); 
    $self->add_entry({ type => "Cell type", label => $f->cell_type->name}); 
    $self->add_entry({ type => "Analysis method", label => $f->analysis->display_label}); 
    $self->{'_sent_caption'} = 1;
  }
  $self->add_entry({ type => "Methylated Reads", 
                    label => sprintf("%d/%d (%d%%)\n",
                                     $f->methylated_reads,
                                     $f->total_reads,
                                     $f->percent_methylation)});
  $self->add_entry({ type => "Strand", label => $f->strand>0?'+ve':'-ve'});
}

sub _menu_setup {
  my ($self, $args) = @_;
  my $hub = $self->hub;

  # Widen to include a few pixels around
  my $fudge = 8/$args->{'scalex'};
  $fudge = 0 if $fudge < 1;
  
  my $r     = $args->{'r'};
  my $id    = uri_unescape($args->{'dbid'});

  my $sa    = $hub->database('core')->get_SliceAdaptor;
  my $slice = $sa->fetch_by_toplevel_location($r)->seq_region_Slice;

  my $fgh   = $hub->database('funcgen');
  my $ch3fa = $fgh->get_DNAMethylationFeatureAdaptor;
  
  my $dma   = $fgh->get_DNAMethylationFileAdaptor;
  my $meth  = $dma->fetch_by_name($id);

  my $bigbed_file = $meth->file;

  # Substitute path, if necessary. 
  my $file_path = join '/', $hub->species_defs->DATAFILE_BASE_PATH, lc $hub->species, $hub->species_defs->ASSEMBLY_VERSION;
  $bigbed_file = "$file_path/$bigbed_file" unless $bigbed_file =~ /^$file_path/;

  ## Clean up any whitespace
  $bigbed_file =~ s/\s//g;

  my $bba = $self->{'_cache'}->{'bigbed_parser'}->{$bigbed_file} 
              ||= Bio::EnsEMBL::IO::Parser::open_as('bigbed', $bigbed_file);

  return ($fudge, $slice, undef, $ch3fa, $bba);
}

sub content {
  my ($self) = @_;

  my $hub     = $self->hub;
  my $r       = $hub->param('r');
  my $s       = $hub->param('click_start');
  my $e       = $hub->param('click_end');
  my $scalex  = $hub->param('scalex');

  $r =~ s/:.*$/:$s-$e/;
  # We need to defeat js-added fuzz to see if it was an on-target click.
  if($e - $s + 1 < 2 * $scalex && $s != $e) { # range within 1px, assume click.
    # fuzz added is symmetric
    $s = ($s + $e - 1) / 2;
    $e = $s + 1;
  }

  my @params = qw(dbid r strand scalex width);
  my %args;

  foreach (@params) {
    $args{$_} = $hub->param($_) if defined($hub->param($_));
  }

  $args{'start'}  = $s;
  $args{'end'}    = $e;

  if($e > $s + 1) {
    $self->summary_zmenu(\%args);
  } else {
    $self->single_base_zmenu(\%args);
  }

}

1;
