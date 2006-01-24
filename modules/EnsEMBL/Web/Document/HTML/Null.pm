package EnsEMBL::Web::Document::HTML::Null;
use strict;

use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::Document::HTML::MastHead;
use EnsEMBL::Web::Document::HTML::SearchBox;
use EnsEMBL::Web::Document::HTML::Content;
use EnsEMBL::Web::Document::HTML::Copyright;
use EnsEMBL::Web::Document::HTML::Menu;
use EnsEMBL::Web::Document::HTML::Release;
use EnsEMBL::Web::Document::HTML::HelpLink;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::Document::HTML
          EnsEMBL::Web::Document::HTML::MastHead
          EnsEMBL::Web::Document::HTML::SearchBox
          EnsEMBL::Web::Document::HTML::Content
          EnsEMBL::Web::Document::HTML::Copyright
          EnsEMBL::Web::Document::HTML::Menu
          EnsEMBL::Web::Document::HTML::Release
          EnsEMBL::Web::Document::HTML::HelpLink );

sub render {
  # Do nothing
}

1;

