package EnsEMBL::Web::Document::HTML::NoRelease;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'version' => '??', 'date' => '??? ????', 'site_name' => '??????' );}
sub version   :lvalue { $_[0]{'version'}; }
sub date      :lvalue { $_[0]{'date'}; }
sub site_name :lvalue { $_[0]{'site_name'}; }
sub dbserver  :lvalue { $_[0]{'dbserver'}; }
sub db        :lvalue { $_[0]{'db'}; }

sub render {
}

1;

