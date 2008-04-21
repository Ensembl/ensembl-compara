package EnsEMBL::Web::Document::HTML::NoMenu;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::Menu;

our @ISA = qw(EnsEMBL::Web::Document::HTML::Menu);

sub site_name          :lvalue { $_[0]{'site_name'}; }

sub render {
}

1;


