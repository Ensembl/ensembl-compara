# $Id$

package EnsEMBL::Web::ZMenu::Synteny;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $sp     = $hub->species;
  my $ref_sp = $hub->referer->{'ENSEMBL_SPECIES'};
  my %clear  = $ref_sp eq $sp ? () : (__clear => 1);
  my $ori    = $hub->param('ori');
  my $r      = $hub->param('r');
  my $r1     = $hub->param('r1');
  
  my ($chr, $loc)    = split ':', $r;
  my ($start, $stop) = split '-', $loc;
  
  $self->caption("$sp $chr:$loc");
  
  if ($r1) {
    my $sp1    = $hub->param('sp1');
    my %clear1 = $ref_sp eq $sp1 ? () : (__clear => 1);
    
    $self->add_entry({
      label => sprintf('%s Chr %s:%0.1fM-%0.1fM', $sp, $chr, $start/1e6, $stop/1e6),
      link  => $hub->url({
        type    => 'Location',
        action  => 'Overview',
        r       => $r,
        %clear
      })
    });
    
    my ($chr1, $loc1)    = split ':', $r1;
    my ($start1, $stop1) = split '-', $loc1;

    $self->add_entry({
      label => sprintf('%s Chr %s:%0.1fM-%0.1fM', $sp1, $chr1, $start1/1e6, $stop1/1e6),
      link  => $hub->url({
        type    => 'Location',
        action  => 'Overview',
        r       => $r1,
        species => $sp1,
        __clear => %clear1
      })
    });
    
    my $new_start = int(($stop+$start)/2) - 5e5;
    my $new_end   = $new_start + 1e6 - 1;
    my $synt_url  = $hub->url({
      type         => 'Location',
      action       => 'Synteny',
      otherspecies => $sp1,
      r            => "$chr:$new_start-$new_end",
      %clear
    });
    
    if ($ori) {
      $self->add_entry({
        label => 'Center display on this chr',
        link  => $synt_url
      });
      
      $self->add_entry({
        label => "Orientation: $ori"
      });
    } else {
      $self->add_entry({
        label => 'Center gene list',
        link  => $synt_url
      });
    }
  } else {
    my ($chr, $loc) = split ':', $r;
    
    $self->add_entry({
      label => "Jump to $sp",
      link  => $hub->url({
        type    => 'Location',
        action  => 'Overview',
        r       => $r,
        %clear
      })
    });
    
    $self->add_entry({
      label => "bp: $loc"
    });
    
    $self->add_entry({
      label => "orientation: $ori"
    });
  }
}

1;
