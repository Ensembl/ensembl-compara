package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new('logins' => '?'); }

sub logins      :lvalue { $_[0]{'logins'};      }
sub blast       :lvalue { $_[0]{'blast'};       }
sub biomart     :lvalue { $_[0]{'biomart'};     }
sub mirror_icon :lvalue { $_[0]{'mirror_icon'}; }

sub render {
  my $self = shift;
  
  my $species_defs = $self->species_defs;
  my $dir          = $species_defs->species_path;
  my $sp_dir       = $ENV{'ENSEMBL_SPECIES'};
  my $blast_dir    = !$sp_dir || $sp_dir eq 'Multi' || $sp_dir eq 'common' ? 'Multi' : $sp_dir;
  
  $dir = '' if $dir !~ /_/;

  my @links;
  
  if ($self->logins) {
    if ($ENV{'ENSEMBL_USER_ID'}) {
      push @links, qq{<a style="display:none" href="$dir/Account/Links" class="modal_link">Account</a>};
      push @links, qq{<a href="$dir/Account/Logout">Logout</a>};
    } else {
      push @links, qq{<a style="display:none" href="$dir/Account/Login" class="modal_link">Login</a>};
      push @links, qq{<a style="display:none" href="$dir/Account/User/Add" class="modal_link">Register</a>};
    }
  }
  
  push @links, qq{<a href="/$blast_dir/blastview">BLAST/BLAT</a>} if $self->blast;
  push @links, qq{<a href="/biomart/martview">BioMart</a>}        if $self->biomart;
  push @links, qq{<a href="/help.html">Help</a>};
  push @links, qq{<a href="/info/docs/">Documentation</a>};
  
  my $last  = pop @links;
  my $tools = join '', map "<li>$_</li>", @links;
  
  $self->print(qq{
    <ul class="tools">$tools<li class="last">$last</li></ul>
    <div class="more">
      <a href="#">More...</a>
    </div>
  });
}

1;

