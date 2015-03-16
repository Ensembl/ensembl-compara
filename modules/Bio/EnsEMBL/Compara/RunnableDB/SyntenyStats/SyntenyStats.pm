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


=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::SyntenyStats

=cut

=head1 DESCRIPTION

Calculate overall and coding coverage statistics for synteny.

=head1 SYNOPSIS

 $ standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::SyntenyStats -division compara_curr -mlss_id 10104 -reg_conf ${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/scripts/pipeline/production_reg_conf.pl

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::SyntenyStats;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::Process');
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub run {
  my ($self) = @_;
  
  $self->syntenic_regions();
  $self->coding_regions();
  $self->calculate_stats();
}

sub syntenic_regions {
  my ($self) = @_;
  my $division = $self->param_required('division');
  my $mlss_id  = $self->param_required('mlss_id');
  my $reg = 'Bio::EnsEMBL::Registry';
  if( $self->param("reg_conf") ){
   Bio::EnsEMBL::Registry->load_all( $self->param("reg_conf") ); 
   $reg->load_all( $self->param("reg_conf") );
  } elsif($self->param("store_in_pipeline_db") ){
   my $pipe_db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( %{ $self->param('pipeline_db') });
  }
  my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($division, 'compara', 'MethodLinkSpeciesSet');
  my $sra = Bio::EnsEMBL::Registry->get_adaptor($division, 'compara', 'SyntenyRegion');
  
  my $mlss = $mlssa->fetch_by_dbID($mlss_id);
  my $synteny_regions = $sra->fetch_all_by_MethodLinkSpeciesSet($mlss);
  
  my %syntenic_regions;
  my %syntenic_lengths;
  foreach my $synteny_region (@$synteny_regions) {
    my $dnafrag_regions = $synteny_region->get_all_DnaFragRegions();
    foreach my $dnafrag_region (@$dnafrag_regions) {
      my $species = $dnafrag_region->genome_db->name;
      my $slice = $dnafrag_region->slice;
      push @{$syntenic_regions{$species}{$slice->seq_region_name}}, [$slice->start, $slice->end];
      $syntenic_lengths{$species} += $dnafrag_region->length;
    }
  }
  
  $self->param('mlss', $mlss);
  $self->param('compara_db', $sra->db);
  $self->param('syntenic_regions', \%syntenic_regions);
  $self->param('syntenic_lengths', \%syntenic_lengths);
}

sub coding_regions {
  my ($self) = @_;
  my @species = keys %{$self->param('syntenic_regions')};
  
  my %total_lengths;
  my %coding_regions;
  my %coding_lengths;
  foreach my $species (@species) {
    my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');
    my $slices = $sa->fetch_all('toplevel');
    foreach my $slice (@$slices) {
      $total_lengths{$species} += $slice->length;
      
      my $genes = $slice->get_all_Genes_by_type("protein_coding");
      while (my $gene = shift @$genes) {
        my $transcripts = $gene->get_all_Transcripts();
        my %exons;
        foreach my $transcript (@$transcripts) {
          my $exons = $transcript->get_all_translateable_Exons();
          foreach my $exon (@$exons) {
            if (!exists $exons{$exon->dbID}) {
              push @{$coding_regions{$species}{$exon->seq_region_name}}, [$exon->start, $exon->end];
              $coding_lengths{$species} += $exon->length;
            }
          }
        }
      }
    }
  }
  
  $self->param('total_lengths', \%total_lengths);
  $self->param('coding_regions', \%coding_regions);
  $self->param('coding_lengths', \%coding_lengths);
}

sub calculate_stats {
	my ($self) = @_;
  
  my $mlss             = $self->param_required('mlss');
  my $mlss_id          = $self->param_required('mlss_id');
  my %syntenic_regions = %{$self->param('syntenic_regions')};
  my %coding_regions   = %{$self->param('coding_regions')};
  my %total_lengths    = %{$self->param('total_lengths')};
  my %syntenic_lengths = %{$self->param('syntenic_lengths')};
  my %coding_lengths   = %{$self->param('coding_lengths')};
  
  my %tags;
  my $prefix = '';
  
  
  foreach my $species (sort keys %syntenic_regions) {
    my $coding_overlap;
    
    foreach my $sr_name (keys $syntenic_regions{$species}) {
      foreach my $syntenic_coords (@{$syntenic_regions{$species}{$sr_name}}) {
       $tags{'num_blocks'}++;
        foreach my $coding_coords (@{$coding_regions{$species}{$sr_name}}) {
          $coding_overlap += $self->coord_intersection($syntenic_coords, $coding_coords);
        }
      }
    }
    $tags{$prefix.'reference_species'} = $species;
    $tags{$prefix.'ref_genome_length'} = $total_lengths{$species};
    $tags{$prefix.'ref_genome_coverage'} = $syntenic_lengths{$species};
    $tags{$prefix.'ref_coding_exon_length'} = $coding_lengths{$species};
    $tags{$prefix.'ref_covered'} = $coding_overlap;
    $tags{$prefix.'ref_uncovered'} = $coding_lengths{$species} - $coding_overlap;
    
    $prefix = 'non_';
  }
  
  my $compara_db = $self->param('compara_db');
  $tags{'ensembl_release'} = $compara_db->get_MetaContainer->get_schema_version();
  
  foreach my $tag (sort keys %tags) {
    $self->warning("store_tag($mlss_id, $tag, ".$tags{$tag}.")");
    $mlss->store_tag($tag, $tags{$tag});
  }
}

# Given two start-stop coordinates, $v and $w, as arrayrefs, work out if they
# overlap. Return the length of the overlapping region.
sub coord_intersection {
	my ($self, $v, $w) = @_;
	my $intersection;

	unless (scalar(@$v) == 2 && scalar(@$w) == 2) {
		$self->throw("Can only calculate intersection of 2D co-ordinates");
	}
	# Sort now to make later calcs simpler.
	my (@v, @w);
	if ($$v[0] <= $$w[0]) {
		@v = sort {$a <=> $b} @$v;
		@w = sort {$a <=> $b} @$w;
	} else {
		@v = sort {$a <=> $b} @$w;
		@w = sort {$a <=> $b} @$v;
	}

	# As we've set it up so that the first element of @v is less
	# than that of @w, we only have three possible scenarios.
	# 1) No overlap, with @v 'to the left of' @w.
	# 2) A partial overlap, with @v straddling the first element of @w.
	# 3) Complete overlap, with @w sitting wholly within @v.
	if ($v[1] < $w[0]) {
		$intersection = 0;
	} elsif ($v[0] <= $w[0] && $v[1] <= $w[1]) {
		$intersection = $v[1] - $w[0] + 1;
	} elsif ($v[0] <= $w[0] && $v[1] >= $w[1]) {
		$intersection = $w[1] - $w[0] + 1;
	} else {
		$self->throw("Failed to calculate intersection of 2D co-ordinates");
	}

	return $intersection;
}

1;
