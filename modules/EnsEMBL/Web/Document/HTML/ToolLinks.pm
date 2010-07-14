package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'logins' => '?' ); }

sub logins      :lvalue { $_[0]{'logins'}; }
sub blast       :lvalue { $_[0]{'blast'}; }
sub biomart     :lvalue { $_[0]{'biomart'}; }
sub mirror_icon :lvalue { $_[0]{'mirror_icon'}; }

sub render {
  my $self = shift;
  
  my $species_defs = $self->species_defs;
  my $dir = $species_defs->species_path;
  $dir = '' if $dir !~ /_/;
  
  my $html = '<div class="print_hide">';

  my $blast_dir;
  my $sp_dir = $ENV{'ENSEMBL_SPECIES'};
  
  if (!$sp_dir || $sp_dir eq 'Multi' || $sp_dir eq 'common') {
    $blast_dir = 'Multi';
  } else {
    $blast_dir = $sp_dir;
  }

  my @links;

  push @links, qq(<a href="/">Genome Browser</a>);
  #push @links, qq(<a href="/downloads.html">Downloads</a>);
  #push @links, qq(<a href="/tools.html">Data Tools</a>);

  push @links, qq(<a href="/$blast_dir/blastview">BLAST/BLAT</a>) if $self->blast;
  push @links, qq(<a href="/biomart/martview">BioMart</a>) if $self->biomart;
  push @links, qq(<a href="/Help/Mirrors" class="modal_link">Mirrors</a>);

  push @links, qq(<a href="/info/" id="help">Documentation</a>);
  push @links, qq(<a href="/help.html" id="help">Help</a>);

  if( $self->logins ) {
    if( $ENV{'ENSEMBL_USER_ID'} ) {
      push @links, qq(
      <a style="display:none" href="$dir/Account/Links" class="modal_link">Account</a> &nbsp;&middot;&nbsp;
      <a href="$dir/Account/Logout">Logout</a>
      );
    } else {
      push @links, qq(
      <a style="display:none" href="$dir/Account/Login" class="modal_link">Login</a> / 
      <a style="display:none" href="$dir/Account/User/Add" class="modal_link">Register</a>
      );
    }
  }

  for (my $i = 0; $i < @links; $i++) {
    $html .= '<td class="lnk_mid">'.$links[$i].'</td>';
  }
  $html .= '</tr>';

  $self->print($html);
}

1;

