# $Id$

package EnsEMBL::Web::ZMenu::PairwiseAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

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
  
  $sp1_display  =~ s/_/ /g;
  
  if ($orient eq 'Forward') {
    $orient = '[+]';
  } elsif ($orient eq 'Reverse') {
    $orient = '[-]';
  }
  ## Display the location of the net and all the links
  if ($n1 and (!$r1 or $r1 ne $n1)) {
    $self->add_subheader("This net: $n1 $orient");

    # Link from the net to the other species
    $url = $hub->url({
      type    => 'Location',
      action  => 'View',
      species => $sp1,
      r       => $n1,
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
        align   => $align,
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
        align   => $align,
      });

      $self->add_entry({
        label => 'Alignments (text)',
        link  => $url,
      });
    }

    if ($n0) {
      # Link from the block to the Multi-species view
      $url = $hub->url({
        type    => 'Location',
        action  => 'Multi',
        r       => $n0,
        r1      => $n1,
        s1      => $sp1,
      });

      $self->add_entry({
        label => 'Multi-species View',
        link  => $url,
      });
    }
  }

  ## Display the location of the block (with a link)
  if ($r1) {
    $self->add_subheader("This block: $r1 $orient");

    # Link from the block to the other species
    $url = $hub->url({
      type    => 'Location',
      action  => 'View',
      species => $sp1,
      r       => $r1,
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
        align   => $align,
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
        align   => $align,
      });

      $self->add_entry({
        label => "Alignments (text)",
        link  => $url,
      });
    }

    # Link from the block to the Multi-species view
    $url = $hub->url({
      type    => 'Location',
      action  => 'Multi',
      r       => $r,
      r1      => $r1,
      s1      => $sp1,
    });

    $self->add_entry({
      label => 'Multi-species View',
      link  => $url,
    });

    # Link from the block to old ComparaGenomicAlignment display
    $url = $hub->url({
      type   => 'Location',
      action => 'ComparaGenomicAlignment', # TODO: does this exist anywhere? doesn't look like it
      s1     => $sp1,
      r1     => $r1,
      method => $disp_method
    });

    $self->add_entry({
      label => 'View alignment',
      link  => $url
    });
  }
  
  $sp1         =~ s/_/ /g;
  $disp_method =~ s/BLASTZ_NET/BLASTz net/g;
  $disp_method =~ s/TRANSLATED_BLAT_NET/Trans. BLAT net/g;
  
  $self->caption("$sp1 - $disp_method");
}

1;
