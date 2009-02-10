package EnsEMBL::Web::Component::Transcript;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component);


use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;
use CGI qw(escapeHTML);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub non_coding_error {
  my $self = shift;
  return $self->_error( 'No protein product', '<p>This transcript does not have a protein product</p>' );
}

sub _flip_URL {
  my( $transcript, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $transcript->species, $transcript->script, $transcript->stable_id, $transcript->get_db, $code;
}


sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;
  
  my $seq;
  my $i = 0;
  
  my $mk = {
    'snp' => { 
      'class' => 'snt', 
      'title' => sub { return "Residues: $_[0]->{'pep_snp'}" }
    },
    'syn' => { 
      'class' => 'sy', 
      'title' => sub { my $p = shift; my $t = ''; $t .= $p->{'ambigcode'}[$_] ? '('.$p->{'ambigcode'}[$_].')' : $p->{'nt'}[$_] for (0..2); return "Codon: $t" }
    },
    'insert' => { 
      'class' => 'sit', 
      'title' => sub { shift; $_->{'alleles'} = join '', @{$_->{'nt'}}; $_->{'alleles'} = Bio::Perl::translate_as_string($_->{'alleles'}); return "Insert: $_->{'alleles'}" }
    },
    'delete' => { 
      'class' => 'sdt', 
      'title' => sub { return "Deletion: $_[0]->{'alleles'}" } 
    },
    'frameshift' => { 
      'class' => 'sf', 
      'title' => sub { return "Frame-shift" }
    },
    'snputr'    => { 'class' => 'snu' },
    'synutr'    => { 'class' => 'syu' },
    'insertutr' => { 'class' => 'siu' },
    'deleteutr' => { 'class' => 'sdu' }
  };

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'variations'}}) {
      my $variation = $data->{'variations'}->{$_};
      my $type = $variation->{'type'};
      
      if ($variation->{'transcript'}) {
        $seq->[$_]->{'title'} = "Alleles: $variation->{'alleles'}";
        $seq->[$_]->{'class'} .= ($config->{'translation'} ? $mk->{$variation->{'type'}}->{'class'} : 'sn') . " ";
      } else {
        $seq->[$_]->{'title'} = &{$mk->{$type}->{'title'}}($variation);
        $seq->[$_]->{'class'} .= "$mk->{$type}->{'class'} ";
      }
    }
    
    $i++;
  }

  $config->{'v_space'} = "\n";
}

sub content_export {
  my $self = shift;
  my $object = $self->object;
  
  my $custom_outputs = {
    'gen_var' => sub { return genetic_variation($object); }
  };
  
  return $self->_export($custom_outputs, [ $object ]);
}


sub genetic_variation {
  my $object = shift;
  
  my $format = $object->param('_format');
  
  my $params;
  map { /opt_pop_(.+)/; $params->{$1} = 1 if $object->param($_) ne 'off' } grep { /opt_pop_/ } $object->param;
  
  my @samples = $object->get_samples(undef, $params);
  
  my $snp_data = genetic_variation_values($object, \@samples);
  
  my $transcript_id = $object->stable_id;
  
  my $header = "<h2>Variation data for strains on transcript $transcript_id</h2>\n";
  $header .= "<p>Format: tab separated per strain (SNP id; Type; Amino acid change;)</p>\n\n";
  
  my $html;
  my $table;
  my $text;
  
  if ($format eq 'Text') {
    $text = join ("\t", ("bp position", @samples)) . "\n";
  } else {    
    $table = new EnsEMBL::Web::Document::SpreadSheet;
    
    $table->add_option('cellspacing', 2);
    $table->add_columns(map {{ 'title' => $_, 'align' => 'left' }} ( 'bp&nbsp;position', @samples ));
  }
  
  my $colours = $object->species_defs->colour('variation');
  my $colour_map = $object->get_session->colourmap;
  
  foreach my $snp_pos (sort keys %$snp_data) {
    my @info = ( $snp_pos );
    my @row_style = ( '' );
    
    foreach my $sample (@samples) {
      if ($snp_data->{$snp_pos}->{$sample}) {
        foreach my $row (@{$snp_data->{$snp_pos}->{$sample}}) {
          (my $type = $row->{'consequence'}) =~ s/\(Same As Ref. Assembly\)//;
          
          my $colour = $row->{'aachange'} eq "-"? '' : $colour_map->hex_by_name($colours->{lc $type}->{'default'});
          
          push @info, "$row->{'ID'}; $type; $row->{'aachange'};";
          push @row_style, $colour ? "background-color:#$colour" : '';
        }
      } else {
        push @info, '';
        push @row_style, '';
      }
    }
    
    if ($format eq 'Text') {
      $text .= join ("\t", @info) . "\n";
    } else {
      $table->add_row(\@info);
      $table->add_option('row_style', \@row_style);
    }
  }
  
  if ($format eq 'Text') {
    $html = "$text\n";
  } else {
    $html = $table->render;
  }
  
  $html ||= "No data available";
  
  return $header . $html;
}

sub genetic_variation_values {
  my ($object, $samples) = @_;
  
  my $tsv_extent = $object->param('context') eq 'FULL' ? 1000 : $object->param('context');
  
  my $snp_data = {};

  foreach my $sample (@$samples) {
    my $munged_transcript = $object->get_munged_slice("tsv_transcript",  $tsv_extent, 1);    
    my $sample_slice = $munged_transcript->[1]->get_by_strain($sample);
    my ($allele_info, $consequences) = $object->getAllelesConsequencesOnSlice($sample, "tsv_transcript", $sample_slice);
    
    next unless @$consequences && @$allele_info;

    my ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);

    my @coverage_obj = sort { $a->start <=> $b->start } @$raw_coverage_obj if @$raw_coverage_obj;
    
    my $index = 0;
    
    foreach my $allele_ref (@$allele_info) {
      my $allele = $allele_ref->[2];
      my $conseq_type = $consequences->[$index];
      
      $index++;
      
      next unless $conseq_type && $allele;

      # Type
      my $type = join ", ", @{$conseq_type->type || []};
      $type .= " (Same As Ref. Assembly)" if ($type eq 'SARA');

      # Position
      my $offset = $sample_slice->strand > 0 ? $sample_slice->start - 1 : $sample_slice->end + 1;
      my $chr_start = $allele->start + $offset;
      my $chr_end = $allele->end + $offset;
      my $pos = $chr_start;
      
      if ($chr_end < $chr_start) {
        $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
      } elsif ($chr_end > $chr_start) {
        $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
      }
      
      my $chr = $sample_slice->seq_region_name;
      my $aa_alleles = $conseq_type->aa_alleles || [];
      my $sources = join ", " , @{$allele->get_all_sources || []};
      my $vid = $allele->variation_name;
      my $source = $allele->source;
      my $vf = $allele->variation->dbID; 
      my $url = $object->_url({'type' => 'Variation', 'action' => 'Summary', 'v' => $vid , 'vf' => $vf, 'source' => $source });
      
      my $row = {
        'ID' => qq{<a href="$url">$vid</a>},
        'consequence' => $type,
        'aachange' => $conseq_type->aa_alleles ? (join "/", @$aa_alleles) || '' : '-'
      };
      
      push @{$snp_data->{"$chr:$pos"}->{$sample}}, $row;
    }
  }
  
  return $snp_data;
} 

1;
