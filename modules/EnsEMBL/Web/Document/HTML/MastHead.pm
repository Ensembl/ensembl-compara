package EnsEMBL::Web::Document::HTML::MastHead;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::MastHead::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'sp_bio' => '?? ??', 'sp_common' => '??', 'site_name' => '??',
                                    'logo_src' => '', 'logo_w' => 40, 'logo_h' => 40, 'sub_title' => undef ); }

sub site_name :lvalue { $_[0]{'site_name'}; }
sub species   :lvalue { $_[0]{'sp_bio'}=~s/ /_/g; $_[0]{'sp_bio'}; }
sub sp_bio    :lvalue { $_[0]{'sp_bio'}=~s/ /_/g; $_[0]{'sp_bio'}; }
sub sp_common :lvalue { $_[0]{'sp_common'}=~s/_/ /g; $_[0]{'sp_common'}; }
sub logo_src  :lvalue { $_[0]{'logo_src'}; }
sub logo_w    :lvalue { $_[0]{'logo_w'};   }
sub logo_h    :lvalue { $_[0]{'logo_h'};   }
sub logo_img  { return sprintf '<img src="%s" style="width: %dpx; height: %dpx; vertical-align:bottom; border:0px; padding-bottom:2px" alt="" title="Home" />',
                               $_[0]->logo_src, $_[0]->logo_w, $_[0]->logo_h ; }
sub sub_title :lvalue { $_[0]{'sub_title'}; }

sub render {
  my @sub_titles = @{[$_[0]->sub_title]};
  if ($sub_titles[0] eq 'HelpView') {
    $_[0]->printf( qq(
<div id="masthead">
  <h1><a href="/">%s</a> <span class="viewname serif">%s</span></h1>
</div>), $_[0]->logo_img, @{[$_[0]->sub_title]}
    );
  }
  else {
    my $species_text = '<span style="font-size: 1.5em; color:#fff">.</span>';
    my $species_name;
    if( $_[0]->sp_bio && $ENV{'ENSEMBL_SPECIES'}) {
      if ($_[0]->sp_common =~ /\./) {
       $species_name = '<i>'.$_[0]->sp_common.'</i>';
      }
      else {
       $species_name = $_[0]->sp_common;
      }
      $species_text = sprintf( '<a href="/%s/" class="section">%s</a>',  $_[0]->sp_bio, $species_name );
      $species_text .= qq( <span class="viewname serif">@{[$_[0]->sub_title]}</span>) if $_[0]->sub_title;
    }
    $_[0]->printf( qq(
<div id="masthead">
  <h1><a href="/">%s</a><a href="/" class="home serif">%s</a> %s</h1>
</div>), $_[0]->logo_img, $_[0]->site_name, $species_text );
  }
}

1;

