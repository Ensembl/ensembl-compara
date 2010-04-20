package EnsEMBL::Web::Data::Bio::Variation;

### NAME: EnsEMBL::Web::Data::Bio::Variation
### Base class - wrapper around a Bio::EnsEMBL::Variation API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Variation

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Converts a set of API objects into simple parameters 
### for use by drawing code and HTML components
  my $self = shift;
  my $data = $self->data_objects;
  my $hub = $self->hub;
  my $results = [];

  my $phenotype_id = $hub->param('id');

  ## getting associated phenotype with the variation
  my $species = $hub->species;
  my $vardb = $hub->database('variation');
  my $vaa = $vardb->get_adaptor("variationannotation");
  my $variation_array = $vaa->fetch_all_by_VariationFeature_list($data);

  foreach my $v (@$data) {
    ## getting all genes located in that specific location
    my ($seq_region, $start, $end ) = ($v->seq_region_name, $v->seq_region_start,$v->end);
    my $slice = $hub->database('core')->get_SliceAdaptor()->fetch_by_region("chromosome", $seq_region, $start, $end);
    my $genes = $slice->get_all_Genes();
    my ($gene_link, $add_comma,$associated_phenotype,$associated_gene,$p_value_log);

    foreach my $row (@$genes) {
      my $gene_symbol;
      $gene_symbol = "(".$row->display_xref->display_id.")" if($row->{'stable_id'});

      my $gene_name = $row->{'stable_id'};
      my $gene_url = $hub->url({ type => 'Gene', action => 'Summary', g => $gene_name});
      $gene_link .= qq{, } if($gene_link);
      $gene_link .= qq{<a href='$gene_url'>$gene_name</a> $gene_symbol};
    }
    my @associated_gene_array;

    ## getting associated phenotype and associated gene with the variation
    foreach my $variation (@$variation_array) {
      ## only get associated gene and phenotype for matching variation id
      if ($variation->{'_variation_id'} eq $v->{'_variation_id'}) {
        if ($associated_phenotype !~ /, $variation->{'phenotype_description'}/) { 
          $associated_phenotype .= qq($variation->{'phenotype_description'}); 
          if ($variation->{'_phenotype_id'} eq $phenotype_id) {
            ## if there is more than one associated gene (comma separated), split them 
            ## to generate the URL for each of them          
            if ($variation->{'associated_gene'} =~ /,/) {
               push @associated_gene_array, (split(/,/,$variation->{'associated_gene'}));
            }
            else {
              push @associated_gene_array, $variation->{'associated_gene'};
            }
            # only get the p value log 10 for the pointer matching phenotype id and variation id
            if ($variation->{'p_value'} != 0) {
              $p_value_log = -(log($variation->{'p_value'})/log(10));  
            }
          }
        }
      }
    }

    ## preparing the URL for all the associated genes and ignoring duplicate one
    foreach my $gene (@associated_gene_array) {
      if ($gene) {
        $gene =~ s/\s//gi;
        my $associated_gene_url = $hub->url({type => 'Gene', action => 'Summary', g => $gene, v => $v->variation_name, vf => $v->dbID});
        $associated_gene .= qq{$gene, } if($gene eq 'Intergenic');
        $associated_gene .= qq{<a href=$associated_gene_url>$gene</a>, } if($associated_gene !~ /$gene/i && $gene ne 'Intergenic');
      }
    }
    $associated_gene =~ s/\s$//g; #removing the last white space
    $associated_gene =~ s/,$|^,//g; #replace the last or first comma if there is any

    $associated_phenotype =~ s/\s$//g; #removing the last white space
    $associated_phenotype =~ s/,$|^,//g; #replace the last or first comma if there is any

    if (ref($v) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($v);
      push(@$results, $unmapped);
    }
    else {
      #making the location 10kb if it a one base pair
      if($v->end-$v->start == 0) {
          $start = $start - 5000;
          $end = $end + 5000;
      }
      push @$results, {
        'region'      => $v->seq_region_name,
        'start'       => $start,
        'end'         => $end,
        'strand'      => $v->strand,
        'label'       => $v->variation_name,
        'href'        => $hub->url({ type => 'Variation', action => 'Variation', v => $v->variation_name, vf => $v->dbID, vdb => 'variation' }),
        'extra'       => [ $gene_link,$associated_gene,$associated_phenotype, sprintf("%.1f",$p_value_log) ],
        'p_value'         => $p_value_log,
        'colour_scaling'  => 1,
      }
    }
  }

  return [$results, ['Located in gene(s)','Associated Gene(s)','Associated Phenotype(s)','P value (negative log)'], 'Variation'];
}


1;
