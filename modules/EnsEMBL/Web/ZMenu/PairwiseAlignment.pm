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

package EnsEMBL::Web::ZMenu::PairwiseAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub method_type {
  my ($self,$id) = @_;

  my $hub = $self->hub;
  my $mlssa = $hub->get_adaptor('get_MethodLinkSpeciesSetAdaptor',
                                'compara');
  return undef unless $mlssa;
  my $mlss = $mlssa->fetch_by_dbID($id);
  return undef unless $mlss;
  my $method = $mlss->method;
  return undef unless $method;
  return $method->type;
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $r           = $hub->param('r');       # Current location or block location
  my $n0          = $hub->param('n0');      # Location of the net on 'this' species
  my $n1          = $hub->param('n1');      # Location of the net on the 'other' species
  my $r1          = $hub->param('r1');      # Location of the block on the 'other' species
  my $sp1         = $hub->param('s1');      # Name of the 'other' species
  my $orient      = $hub->param('orient');
  my $disp_method = $hub->param('method');
  my $align       = $hub->param('align');
  my $sp1_display = $sp1;
  my $url;
  
  my $page_action = $hub->referer->{'ENSEMBL_ACTION'};

  $sp1_display  =~ s/_/ /g;
  $disp_method =~ s/(B?)LASTZ_NET/$1LASTz net/g;
  $disp_method =~ s/TRANSLATED_BLAT_NET/Trans. BLAT net/g;
  
  $self->caption("$sp1_display - $disp_method");

  if ($orient eq 'Forward') {
    $orient = '[+]';
  } elsif ($orient eq 'Reverse') {
    $orient = '[-]';
  }

  if ($disp_method eq 'CACTUS_HAL_PW') {
    ## Keep things simple for CACTUS
    $self->add_subheader("This region maps to:");
    my $display = $hub->species_defs->get_config($sp1, 'SPECIES_DISPLAY_NAME');

    $url = $hub->url({
      type    => 'Location',
      action  => 'View',
      species => $sp1,
      r       => $r1,
      __clear => 1
    });

    $self->add_entry({
      label => "$display $r1 $orient",
      link  => $url,
    });

  }
  else {
  
  ## Display the location of the net and all the links
    if ($n1 and (!$r1 or $r1 ne $n1)) {
      my $type = $self->method_type($align);
      my $name = "region maps to";
      $self->add_subheader("This $name: $n1 $orient");

      # Link from the net to the other species
      $url = $hub->url({
        type    => 'Location',
        action  => 'View',
        species => $sp1,
        r       => $n1,
        __clear => 1
      });

      $self->add_entry({
        label => "Jump to $sp1_display",
        link  => $url,
      });

      if ($n0 and $align) {
        # Link from the net to the Alignment view (in graphic mode)
        $url = $hub->url({
          type    => 'Location',
          action  => 'Compara_Alignments/Image',
          r       => $n0,
          align   => ($n1 ? "$align--$sp1--$n1" : $align),
        });

        $self->add_entry({
          label => 'Alignments (image)',
          link  => $url,
        });

        # Link from the block to the Alignment view (in text mode)
        $url = $hub->url({
          type    => 'Location',
          action  => 'Compara_Alignments',
          r       => $n0,
          align   => ($n1 ?  "$align--$sp1--$n1" : $align),
        });

        $self->add_entry({
          label => 'Alignments (text)',
          link  => $url,
        });
      }

      if ($n0 && $page_action ne 'Multi') {
        # Link from the block to the Multi-species view
        $url = $hub->url({
          type    => 'Location',
          action  => 'Multi',
          r       => $n0,
          r1      => $n1,
          s1      => $sp1,
        });

        $self->add_entry({
          label => 'Region Comparison View',
          link  => $url,
        });
      }
    }

    ## Display the location of the block (with a link)
    if ($r1) {
      $self->add_subheader("This block maps to: $r1 $orient");

      # Link from the block to the other species
      $url = $hub->url({
        type    => 'Location',
        action  => 'View',
        species => $sp1,
        r       => $r1,
        __clear => 1
      });

      $self->add_entry({
        label => "Jump to $sp1_display",
        link  => $url,
      });

      if ($r and $align) {
        # Link from the block to the Alignment view (in graphic mode)
        $url = $hub->url({
          type    => 'Location',
          action  => 'Compara_Alignments/Image',
          r       => $r,
          align   => ($r1 ?  "$align--$sp1--$r1" : $align),
        });

        $self->add_entry({
          label => "Alignments (image)",
          link  => $url,
        });

        # Link from the block to the Alignment view (in text mode)
        $url = $hub->url({
          type    => 'Location',
          action  => 'Compara_Alignments',
          r       => $r,
          align   => ($r1 ?  "$align--$sp1--$r1" : $align),
        });

        $self->add_entry({
          label => "Alignments (text)",
          link  => $url,
        });
      }

      unless ($page_action eq 'Multi') {
        # Link from the block to the Multi-species view
        $url = $hub->url({
          type    => 'Location',
          action  => 'Multi',
          r       => $r,
          r1      => $r1,
          s1      => $sp1,
        });

        $self->add_entry({
          label => 'Region Comparison View',
          link  => $url,
        });
      }
    }
  } 
}

1;
