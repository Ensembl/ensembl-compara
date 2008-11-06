package EnsEMBL::Web::Form::Element;

sub required_string { return '<strong title="required field">*</strong>'; }
sub required_value { return '[required]'; }

sub new {
  my( $class, %array ) = @_;
  my $self = {
    'form'         => $array{ 'form'  },
    'id'           => $array{ 'id'  },
    'type'         => $array{ 'type'  },
    'value'        => $array{ 'value' },
    'default'      => $array{ 'default' },
    'values'       => $array{ 'values' } || {},
    'widget_type'  => $array{ 'widget_type'} || 'text',
    '_validate'    => 0,
    'layout'       => $array{ 'layout'}    || 'normal',
    'name'         => $array{ 'name' },
    'size'         => $array{ 'size' },
    'rows'         => $array{ 'rows' },
    'cols'         => $array{ 'cols' },
    'required'     => $array{ 'required' },
    'notes'        => $array{ 'notes' },
    'bg'           => $array{ 'bg' },
    'style'        => $array{ 'style' } || 'normal',
    'classes'      => $array{ 'classes' } || [],
    'styles'       => $array{ 'styles' } || [],
    'introduction' => $array{ 'introduction' },
    'label'        => $array{ 'label' },
    'comment'      => $array{ 'comment' },
    'hidden_label' => $array{ 'hidden_label' },
    'render_as'    => $array{ 'render_as'    },
    'src'          => $array{ 'src'    },
    'alt'          => $array{ 'alt'    },
    'width'        => $array{ 'width' },
    'height'       => $array{ 'height' },
    'noescape'     => $array{ 'noescape' },
    'raw'          => $array{ 'raw' } || 0,
    'in_error'     => 'no'
  };
  bless $self, $class;
  return $self; 
}

sub form         :lvalue { $_[0]{'form'};   }
sub id           :lvalue { $_[0]{'id'};   }
sub type         :lvalue { $_[0]{'type'}; }
sub value        :lvalue { $_[0]{'value'}; }
sub default      :lvalue { $_[0]{'default'}; }
sub values       :lvalue { $_[0]{'values'}; }
sub style        :lvalue { $_[0]{'style'}; }
sub styles       :lvalue { $_[0]{'styles'}; }
sub classes      :lvalue { $_[0]{'classes'}; }
sub widget_type  :lvalue { $_[0]{'widget_type'}; }
sub _validate    :lvalue { $_[0]{'_validate'}; }
sub layout       :lvalue { $_[0]{'layout'}; }
sub name         :lvalue { $_[0]{'name'}; }
sub size         :lvalue { $_[0]{'size'}; }
sub rows         :lvalue { $_[0]{'rows'}; }
sub cols         :lvalue { $_[0]{'cols'}; }
sub required     :lvalue { $_[0]{'required'}; }
sub notes        :lvalue { $_[0]{'notes'}; }
sub introduction :lvalue { $_[0]{'introduction'}; }
sub label        :lvalue { $_[0]{'label'}; }
sub comment      :lvalue { $_[0]{'comment'}; }
sub hidden_label :lvalue { $_[0]{'hidden_label'}; }
sub in_error     :lvalue { $_[0]{'in_error'}; }
sub render_as    :lvalue { $_[0]{'render_as'}; }
sub raw          :lvalue { $_[0]{'raw'};   }
sub src          :lvalue { $_[0]{'src'};   }
sub alt          :lvalue { $_[0]{'alt'};   }
sub width        :lvalue { $_[0]{'width'};   }
sub height       :lvalue { $_[0]{'height'};   }
sub noescape     :lvalue { $_[0]{'noescape'};   }

sub _is_valid    { return 1; }
sub validate     { return $_[0]->required eq 'yes'; }
sub _extra       { return ''; }

sub add_class {
  my ($self, $class) = @_;
  return unless $class;
  my $aref = $self->classes; 
  return if grep(/^$class$/, @$aref); 
  push @$aref, $class;
  $self->classes($aref);
}

sub add_style {
  my ($self, $style) = @_;
  return unless $style;
  my $aref = $self->styles; 
  return if grep(/^$style$/, @$aref); 
  push @$aref, $style;
  $self->styles($aref);
}

sub class_attrib {
  my $self = shift;
  my $attrib = '';
  if (scalar(@{$self->classes})) {
    $attrib = ' class="'.join(' ', @{$self->classes}).'"';
  }
  return $attrib;
}

sub style_attrib {
  my $self = shift;
  my $attrib = '';
  if (scalar(@{$self->styles})) {
    $attrib = ' style="'.join(';', @{$self->styles}).'"';
  }
  return $attrib;
}

1;

