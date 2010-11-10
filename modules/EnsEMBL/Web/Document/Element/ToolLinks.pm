# $Id$

package EnsEMBL::Web::Document::Element::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub logins  :lvalue { $_[0]{'logins'};  }
sub blast   :lvalue { $_[0]{'blast'};   }
sub biomart :lvalue { $_[0]{'biomart'}; }

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
     $species = !$species || $species eq 'Multi' || $species eq 'common' ? 'Multi' : $species;
  my @links;
  
  if ($self->logins) {
    if ($hub->user) {
      push @links, sprintf '<a class="constant modal_link" style="display:none" href="%s">Account</a>',  $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'Links'  });
      push @links, sprintf '<a class="constant" href="%s">Logout</a>',                                   $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'Logout' });
    } else {
      push @links, sprintf '<a class="constant modal_link" style="display:none" href="%s">Login</a>',    $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'Login' });
      push @links, sprintf '<a class="constant modal_link" style="display:none" href="%s">Register</a>', $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'User', function => 'Add' });
    }
  }
  
  push @links, qq{<a class="constant" href="/$species/blastview">BLAST/BLAT</a>} if $self->blast;
  push @links,   '<a class="constant" href="/biomart/martview">BioMart</a>'      if $self->biomart;
  push @links,   '<a class="constant" href="/tools.html">Tools</a>';
  push @links,   '<a class="constant" href="/downloads.html">Downloads</a>';
  push @links,   '<a class="constant" href="/help.html">Help</a>';
  push @links,   '<a class="constant" href="/info/docs/">Documentation</a>';
  push @links,   '<a class="constant modal_link" href="/Help/Mirrors">Mirrors</a>' if keys %{$hub->species_defs->ENSEMBL_MIRRORS || {}};

  my $last  = pop @links;
  my $tools = join '', map "<li>$_</li>", @links;
  
  return qq{
    <ul class="tools">$tools<li class="last">$last</li></ul>
    <div class="more">
      <a href="#">More...</a>
    </div>
  };
}

sub init {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  $self->logins    = $species_defs->ENSEMBL_LOGINS;
  $self->blast     = $species_defs->ENSEMBL_BLAST_ENABLED;
  $self->biomart   = $species_defs->ENSEMBL_MART_ENABLED;
}

1;
