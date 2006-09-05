package EnsEMBL::Web::Component::User;

use EnsEMBL::Web::Component;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);


sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

##-----------------------------------------------------------------

sub accountview {
  my( $panel, $object ) = @_;
  my $html;

  my $id = $object->get_user_id;
  $html .= _show_details($panel, $object, $id);
  $html .= _show_bookmarks($panel, $object, $id);
  $html .= _show_blast($panel, $object, $id);

  $panel->print($html);
  return 1;
}

sub _show_details {
  my( $panel, $object, $id ) = @_;

  my %details = %{$object->get_user_by_id($id)};

## Get the user's full name
  my $name  = $details{'name'};
  my $email = $details{'email'};
  my $org   = $details{'org'};

## return the message
  my $html = "<h3>Personal details</h3>";

  $html .= qq(<p><strong>Name</strong>: $name</p>
<p><strong>Email address</strong>: $email</p>
<p><strong>Organisation</strong>: $org</p>
<p><a href="/common/update_account">Update account details</a> | <a href="/common/set_password">Change password</a></p>);

  return $html;
}

sub _show_bookmarks {
  my( $panel, $object, $id ) = @_;
  my $editable = $panel->ajax_is_available;
  ## Get the user's bookmark list
  my @bookmarks = @{$object->get_bookmarks($id)};

  ## return the message
  my $html = "<h3>My bookmarks</h3>\n";

  if (scalar(@bookmarks) > 0) {
    if ($editable) {
      $html .= _show_editable_bookmarks(@bookmarks);
    } else {
      $html .= _show_static_bookmarks(@bookmarks);
    }
  }
  else {
    $html .= "<p>You have no bookmarks set.</p>";
  }

  return $html;
}

sub _show_static_bookmarks {
    my @bookmarks = @_;
    my $html = "<ul>\n";
    foreach my $bookmark (@bookmarks) {
      my $name = $$bookmark{'bm_name'};
      my $url  = $$bookmark{'bm_url'};
      $html .= qq(<li><a href="$url">$name</a></li>);
    }
    $html .= qq(</ul>
<p><a href="/common/manage_bookmarks">Manage bookmarks</a></p>);
    return $html;
}

sub _show_editable_bookmarks {
    my @bookmarks = @_;
    my $html = "<div>";
    my $count = 0;
    foreach my $bookmark (@bookmarks) {
      my $name = $$bookmark{'bm_name'};
      my $url  = $$bookmark{'bm_url'};
      $html .= _inplace_editor_for_bookmarks($count, $bookmark) . qq(<div class='bookmark_item' onmouseover="show_manage_links('bookmark_manage_$count')" onmouseout="hide_manage_links('bookmark_manage_$count')" id='bookmark_$count'><span class='bullet'><img src='/img/red_bullet.gif' width='4' height='8'></span><a href="$url" title='$url' id='bookmark_name_$count'>$name</a>) . _manage_links($count, $bookmark) . qq(</div>);
      $count++;
    }
    $html .= "</div>";
    return $html;
}

sub _manage_links {
  my ($id, $bookmark) = @_;
  my $bookmark_id   = $$bookmark{'bm_id'};
  my $user_id = $ENV{'ENSEMBL_USER_ID'}; 
  my $html = qq(<div class="bookmark_manage" style='display: none;' id='bookmark_manage_$id'><a href='#' onclick='javascript:show_inplace_editor($id);'>edit</a> &middot; <a href='#' onclick='javascript:delete_bookmark($id, $bookmark_id, $user_id)'>delete</a></div>);
  return $html;
}

sub _inplace_editor_for_bookmarks {
  my ($id, $bookmark) = @_;
  my $bookmark_id   = $$bookmark{'bm_id'};
  my $bookmark_url   = $$bookmark{'bm_url'};
  my $user_id = $ENV{'ENSEMBL_USER_ID'}; 
  my $html = "<div id='bookmark_editor_$id' class='bookmark_editor' style='display: none'><form action='javascript:save_bookmark($id, $bookmark_id, $user_id);'><input type='text' id='bookmark_text_field_$id' value='" . $$bookmark{'bm_name'} . "'> <div id='bookmark_editor_spinner_$id' style='display: none'><img src='/img/ajax-loader.gif' width='16' height='16' />'</div><div style='display: inline' id='bookmark_editor_links_$id'><a href='#' onclick='javascript:save_bookmark($id, $bookmark_id, $user_id);'>save</a> &middot; <a href='#' onclick='javascript:hide_inplace_editor($id);'>cancel</a></div></form></div>";
  return $html;
}

sub _show_blast {
  my( $panel, $object, $id ) = @_;

## Get the user's BLAST ticket list
  my $blast = {};

## return the message
  my $html = "<h3>My BLAST tickets</h3>\n";

  if (keys %$blast) {
    $html .= "<ul>\n";
    while( my ($text, $url) = each %$blast) {
      $html .= qq(<li><a href="$url">$text</a></li>);
    }
    $html .= "</ul>\n";
  }
  else {
    $html .= "<p>You do not have any saved BLAST tickets.</p>";
  }

  return $html;
}

sub denied {
  my( $panel, $object ) = @_;

## return the message
  my $html = qq(<p>Sorry - this page requires you to be logged into your Ensembl user account and to have the appropriate permissions. If you cannot log in or need your access privileges changed, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>);

  $panel->print($html);
  return 1;
}

##-----------------------------------------------------------------
## USER REGISTRATION COMPONENTS    
##-----------------------------------------------------------------

sub login {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:50%">);
  $html .= $panel->form('login')->render();
  $html .= qq(<p><a href="/common/register">Register</a> | <a href="/common/lost_password">Lost password</a></p>);
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub enter_details   { 
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if (!$object->param('email')) { ## new registration
    $html .= qq(<p><strong>Register with Ensembl to bookmark your favourite pages, manage your BLAST tickets and more!</strong></p>);
  }

  $html .= $panel->form('details')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub preview           { _wrap_form($_[0], $_[1], 'preview'); }

sub enter_password      { 
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if ($object->param('code')) { ## resetting lost password
    $html .= qq(<p><strong>Please enter a new password to reactivate your account.</strong></p>);
  }

  $html .= $panel->form('enter_password')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub enter_email {
  my ( $panel, $object ) = @_;
  
  my $help_email  = $object->species_defs->ENSEMBL_HELPDESK_EMAIL;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= qq(<p>Please note that information on resetting your password will be emailed to your <strong>current registered email address</strong>. If you have changed your email address as well as losing your password, please contact <a href="mailto:$help_email">$help_email</a> for assistance. Thank you.</p>);
  $html .= $panel->form('enter_email')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub thanks_lost {
  my ( $panel, $object ) = @_;
  my $exp_text = $panel->{wizard}->data('exp_text');

  my $html = qq(<p>An activation code has been sent to your registered email address; follow the enclosed instructions to log back in and reset your password.</p>
<p>Please note that the code expires after $exp_text.</p>
);
    
  $panel->print($html);
  return 1;
}


sub thanks_reg {
  my ( $panel, $object ) = @_;
  my $exp_text = $panel->{wizard}->data('exp_text');

  my $website   = $ENV{'SERVER_SITETYPE'};
  my $html =  qq(<p>Thank you for registering with $website. An email has been sent to your address with an activation code; follow the instructions to return to this website and activate your new account.</p>
<p>Please note that the code expires after $exp_text.</p>
);

  $panel->print($html);
  return 1;
}


##-----------------------------------------------------------------
## USER CUSTOMISATION COMPONENTS    
##-----------------------------------------------------------------

sub select_bookmarks {
  my ( $panel, $object, $node ) = @_;

  ## Get the user's bookmark list
  my $id = $object->get_user_id;
  my @bookmarks = @{$object->get_bookmarks($id)};

  my $html = qq(<div class="formpanel" style="width:80%">);
  if (scalar(@bookmarks)) {
    $html .= $panel->form($node)->render();
  }
  else {
    $html .= qq(<p>You have no bookmarks set at the moment. To set a bookmark, go to any Ensembl content page whilst logged in (any 'view' page such as GeneView, or static content such as documentation), and click on the "Bookmark this page" link in the lefthand menu.</p>);
  }
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

sub name_bookmark     { _wrap_form($_[0], $_[1], 'name_bookmark'); }

1;

