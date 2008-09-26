package EnsEMBL::Web::Document::HTML::LocalContext;

### Generates the local context navigation menu, used in dynamic pages

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( 'counts' => {}, 'tree' => undef, 'active' => undef, 'caption' => 'Local context' );
  return $self;
}

sub tree {
  ### a
  my $self = shift;
  $self->{tree} = shift if @_;
  return $self->{tree};
}

sub active {
  ### a
  my $self = shift;
  $self->{active} = shift if @_;
  return $self->{active};
}
sub class {
  ### a
  my $self = shift;
  $self->{class} = shift if @_;
  return $self->{class};
}

sub caption {
  ### a
  my $self = shift;
  $self->{caption} = shift if @_;
  return $self->{caption};
}

sub counts {
  ### a
  my $self = shift;
  $self->{counts} = shift if @_;
  return $self->{counts};
}

sub render_modal {
  my $self = shift;
  my $t = $self->_content;
     $t =~ s/id="local"/id="local_modal"/;
  return $self->print( $t );
}

sub render {
  my $self = shift;
  return $self->print( $self->_content );
}

sub _content {
  my $self = shift;
  my $t = $self->tree;
  my $content = sprintf( q(
      <dl id="local"%s>
        <dt>%s</dt>),
    $self->{'class'} ? qq( class="$self->{class}") : '',
    $self->caption
  );
  return "$content\n      </dl>" unless $t;
  my $r = 0;
  my $previous_node;
  my $active = $self->active;
  my @n = $t->nodes;
  my $active_node = $t->get_node( $active ) || $n[0];
  return "$content\n      </dl>" unless $active_node;
  my $active_l    = $active_node->left;
  my $active_r    = $active_node->right;
  my $counts = $self->counts;
  my $pad = '';
  foreach my $node ( @n ) {
    my $no_show = 1 if $node->data->{'no_menu_entry'};
    $r = $node->right if $node->right > $r;
    if( $previous_node && $node->left > $previous_node->right ) {
      foreach(1..($node->left - $previous_node->right-1)) {
        $content .= "
$pad      </dl>
$pad    </dd>";
        substr($pad,0,4)='';
      }
    }
    unless ($no_show) {
      my $name = $node->data->{caption};
      $name =~ s/\[\[counts::(\w+)\]\]/$counts->{$1}||0/eg;
      $name = CGI::escapeHTML( $name );
      if( $node->data->{'availability'} ) {
        my $url = $node->data->{'url'};
        if (!$url) {
          $url = '/'.$ENV{'ENSEMBL_SPECIES'}.'/'.$ENV{'ENSEMBL_TYPE'}.'/'.$node->data->{'code'}.'?'.$ENV{'QUERY_STRING'};
        }
      	$name = sprintf '<a href="%s" title="%s">%s</a>', $url, $name, $name;
      } else {
      	$name = sprintf('<span class="disabled" title="%s">%s</span>', $node->data->{'disabled'}, $name);
      }
      my $row_content = '';
      if( $node->is_leaf ) {
	$content .= sprintf( qq(
$pad        <dd%s%s>%s</dd>), 
              $node->data->{'id'} ? ' id="'.$node->data->{'id'}.'"' : '',
              $node->key eq $active ? ' class="active"' : '', $name );
      }
      else {
        $content .= sprintf( qq(
$pad        <dd class="%s">%s
$pad          <dl>),
        ($node->left <= $active_l && $node->right >= $active_r ? 'open' : 'open').
	  $node->key eq $active ? ' active' :'',
	$name );
	$pad .= '    ';
      }
    }
    $previous_node = $node;
  }
  foreach(($previous_node->right+1)..$r) {
    $content .= qq(
$pad      </dl>
$pad    </dd>);
    substr($pad,0,4)='';
  }
  $content .= q(
      </dl>);
  return $content;
}

return 1;
