package EnsEMBL::Web::Document::HTML::NoHelpLink;
use strict;
use CGI qw(escapeHTML escape);
use EnsEMBL::Web::Document::HTML;

use constant HELPVIEW_WIN_ATTRIBS => "width=700,height=550,resizable,scrollbars,toolbar";

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new           {
  return shift->SUPER::new(
    'kw'    => undef,
    'label' => 'Help',
  ); 
}
sub URL    :lvalue { $_[0]{'URL'};   }
sub kw     :lvalue { $_[0]{'kw'};    }
sub ref    :lvalue { $_[0]{'ref'};   }
sub action :lvalue { $_[0]{'action'};   }
sub label  :lvalue { $_[0]{'label'};    }
sub simple :lvalue { $_[0]{'simple'}; }

sub render {
}

1;

