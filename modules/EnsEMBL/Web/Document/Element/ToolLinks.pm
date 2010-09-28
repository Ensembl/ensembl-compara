# $Id$

package EnsEMBL::Web::Document::Element::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    logins => '?'
  });
}

sub logins  :lvalue { $_[0]{'logins'};  }
sub blast   :lvalue { $_[0]{'blast'};   }
sub biomart :lvalue { $_[0]{'biomart'}; }

sub content {
  my $self = shift;
  
  my $species_defs = $self->species_defs;
  my $dir          = $species_defs->species_path;
  my $sp_dir       = $ENV{'ENSEMBL_SPECIES'};
  my $blast_dir    = !$sp_dir || $sp_dir eq 'Multi' || $sp_dir eq 'common' ? 'Multi' : $sp_dir;
  
  $dir = '' if $dir !~ /_/;

  my @links;
  
  if ($self->logins) {
    if ($ENV{'ENSEMBL_USER_ID'}) {
      push @links, qq{<a class="constant modal_link" style="display:none" href="$dir/Account/Links">Account</a>};
      push @links, qq{<a class="constant" href="$dir/Account/Logout">Logout</a>};
    } else {
      push @links, qq{<a class="constant modal_link" style="display:none" href="$dir/Account/Login">Login</a>};
      push @links, qq{<a class="constant modal_link" style="display:none" href="$dir/Account/User/Add">Register</a>};
    }
  }
  
  push @links, qq{<a class="constant" href="/$blast_dir/blastview">BLAST/BLAT</a>} if $self->blast;
  push @links, qq{<a class="constant" href="/biomart/martview">BioMart</a>}        if $self->biomart;
  push @links, qq{<a class="constant" href="/tools.html">Tools</a>};
  push @links, qq{<a class="constant" href="/downloads.html">Downloads</a>};
  push @links, qq{<a class="constant" href="/help.html">Help</a>};
  push @links, qq{<a class="constant" href="/info/docs/">Documentation</a>};

  if ($species_defs->ENSEMBL_MIRRORS && keys %{$species_defs->ENSEMBL_MIRRORS}) {
    push @links, qq(<a class="constant modal_link" href="/Help/Mirrors">Mirrors</a>);
  }

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
