package EnsEMBL::Web::Component::Variation::Mappings;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}


sub content {
  my $self = shift;
  my $object = $self->object;

  # first check we have uniquely determined variation
  if ($object->not_unique_location) {
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
    );
  }

  my %mappings = %{$object->variation_feature_mapping};

  return [] unless keys %mappings;

  my $source = $object->source;
  my $name   = $object->name;
 
  my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '1em 0px' });
  $table->add_columns(
    { key => 'gene',      title => 'Gene' },
    { key => 'trans',     title => 'Transcript' },
    { key => 'type',      title => 'Type' },     
    { key => 'trans_pos', title => 'Relative position in transcript', align =>'center' },
    { key => 'prot_pos',  title => 'Relative position in protein',    align => 'center' },
    { key => 'aa',        title => 'Amino acid' },
  );
  
  my $tsv_species  = ($object->species_defs->VARIATION_STRAIN &&  $object->species_defs->get_db eq 'core') ? 1 : 0;
  my $gene_adaptor = $object->database('core')->get_GeneAdaptor();
  my %genes;
  my $flag;
  
  foreach my $varif_id (keys %mappings) {
    # Check vari feature s the one we are intrested in
    next unless $varif_id  eq $object->param('vf');
    
    my @transcript_variation_data = @{$mappings{$varif_id}{'transcript_vari'}};
    
    next unless scalar @transcript_variation_data;

    foreach my $transcript_data (@transcript_variation_data) {
      my $gene         = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{'transcriptname'}); 
      my $gene_name    = $gene->stable_id if $gene;
      my $trans_name   = $transcript_data->{'transcriptname'}; 
      my $trans_coords = $self->_sort_start_end($transcript_data->{'cdna_start'}, $transcript_data->{'cdna_end'});
      my $pep_coords   = $self->_sort_start_end($transcript_data->{'translation_start'}, $transcript_data->{'translation_end'});
      my $type         = $transcript_data->{'conseq'};
      my $aa           = $transcript_data->{'pepallele'} || 'n/a';
      
      my $gene_url = $object->_url({
        type   => 'Gene',
        action => 'Variation_Gene',
        db     => 'core',
        r      => undef,
        g      => $gene_name,
        v      => $name,
        source => $source
      });
      
      my $transcript_url = $object->_url({
        type   => 'Transcript',
        action => $object->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
        db     => 'core',
        r      => undef,
        t      => $trans_name,
        v      => $name,
        source => $source
      });

      # Now need to add to data to a row, and process rows somehow so that a gene ID is only displayed once, regardless of the number of transcripts;
      my $row = {
        trans     => qq{<a href="$transcript_url">$trans_name</a>},
        type      => $type,
        trans_pos => $trans_coords,
        prot_pos  => $pep_coords,
        aa        => $aa
      };
      
      if (exists $genes{$gene_name}) { 
         push @{$genes{$gene_name}}, $row;
      } else {
         $row->{'gene'} = qq{<a href="$gene_url">$gene_name</a>};
         $genes{$gene_name} = [ $row ]; 
      }
    }
    
    $flag = 1;
    
    foreach my $g (keys %genes) {
      $table->add_row($_) for @{$genes{$g}};
    }
  }

  if ($flag) { 
    return $table->render;
  } else { 
    return $self->_info('', '<p>This variation has not been mapped any Ensembl genes or transcripts</p>');
  }
}

# Mapping_table
# Arg1     : start and end coordinate
# Example  : $coord = _sort_star_end($start, $end)_
# Description : Returns $start-$end if they are defined, else 'n/a'
# Returns  string
sub _sort_start_end {
  my ($self, $start, $end) = @_;
  
  if ($start || $end) {
    return " $start-$end&nbsp;";
  } else {
    return " n/a&nbsp;"
  };
}

1;
