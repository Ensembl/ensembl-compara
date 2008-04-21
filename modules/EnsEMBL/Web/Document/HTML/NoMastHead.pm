package EnsEMBL::Web::Document::HTML::NoMastHead;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub site_name :lvalue { $_[0]{'site_name'}; }
sub species   :lvalue { $_[0]{'sp_bio'}=~s/ /_/g; $_[0]{'sp_bio'}; }
sub sp_bio    :lvalue { $_[0]{'sp_bio'}=~s/ /_/g; $_[0]{'sp_bio'}; }
sub sp_common :lvalue { $_[0]{'sp_common'}=~s/_/ /g; $_[0]{'sp_common'}; }
sub logo_src  :lvalue { $_[0]{'logo_src'}; }
sub logo_w    :lvalue { $_[0]{'logo_w'};   }
sub logo_h    :lvalue { $_[0]{'logo_h'};   }
sub logo_href :lvalue { $_[0]{'logo_href'};   }
sub logo_img  { return undef; }
sub sub_title :lvalue { $_[0]{'sub_title'}; }

sub new { return shift->SUPER::new(); }

sub render {
}

1;

