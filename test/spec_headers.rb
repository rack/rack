# frozen_string_literal: true

require_relative 'helper'

separate_testing do
  require_relative '../lib/rack/headers'
end

class RackHeadersTest < Minitest::Spec
  before do
    @h = Rack::Headers.new
    @fh = Rack::Headers['AB'=>'1', 'cd'=>'2', '3'=>'4']
  end

  def test_public_interface
    headers_methods = Rack::Headers.public_instance_methods.sort
    hash_methods = Hash.public_instance_methods.sort
    assert_empty(headers_methods - hash_methods)
    assert_empty(hash_methods - headers_methods)
  end

  def test_class_aref
    assert_equal Hash[], Rack::Headers[]
    assert_equal Hash['a'=>'2'], Rack::Headers['A'=>'2']
    assert_equal Hash['a'=>'2', 'b'=>'4'], Rack::Headers['A'=>'2', 'B'=>'4']
    assert_equal Hash['a','2','b','4'], Rack::Headers['A','2','B','4']
    assert_raises(ArgumentError){Rack::Headers['A']}
    assert_raises(ArgumentError){Rack::Headers['A',2,'B']}
  end

  def test_default_values
    h, ch = Hash.new, Rack::Headers.new
    assert_equal h, ch
    h, ch = Hash.new('1'), Rack::Headers.new('1')
    assert_equal h, ch
    assert_equal h['3'], ch['3']
    h['a'], ch['A'] = ['2', '2']
    assert_equal h['a'], ch['a']
    h, ch = Hash.new{|h,k| k*2}, Rack::Headers.new{|h,k| k*2}
    assert_equal h['3'], ch['3']
    h['c'], ch['C'] = ['2', '2']
    assert_equal h['c'], ch['c']
    assert_raises(ArgumentError){Rack::Headers.new('1'){|hash,k| key}}

    assert_nil @fh.default
    assert_nil @fh.default_proc
    assert_nil @fh['55']
    assert_equal '3', Rack::Headers.new('3').default
    assert_nil Rack::Headers.new('3').default_proc
    assert_equal '3', Rack::Headers.new('3')['1']

    @fh.default = '4'
    assert_equal '4', @fh.default
    assert_nil  @fh.default_proc
    assert_equal '4', @fh['55']

    h = Rack::Headers.new('5')
    assert_equal '5', h.default
    assert_nil  h.default_proc
    assert_equal '5', h['55']

    h = Rack::Headers.new{|hash, key| '1234'}
    assert_nil  h.default
    refute_equal nil, h.default_proc
    assert_equal '1234', h['55']

    h = Rack::Headers.new{|hash, key| hash[key] = '1234'; nil}
    assert_nil  h.default
    refute_equal nil, h.default_proc
    assert_nil  h['Ac']
    assert_equal '1234', h['aC']
  end

  def test_store_and_retrieve
    assert_nil  @h['a']
    @h['A'] = '2'
    assert_equal '2', @h['a']
    assert_equal '2', @h['A']
    @h['a'] = '3'
    assert_equal '3', @h['a']
    assert_equal '3', @h['A']
    @h['AB'] = '5'
    assert_equal '5', @h['ab']
    assert_equal '5', @h['AB']
    assert_equal '5', @h['aB']
    assert_equal '5', @h['Ab']
    @h.store('C', '8')
    assert_equal '8', @h['c']
    assert_equal '8', @h['C']
  end

  def test_clear
    assert_equal 3, @fh.length
    @fh.clear
    assert_equal Hash[], @fh
    assert_equal 0, @fh.length
  end

  def test_delete
    assert_equal 3, @fh.length
    assert_equal '1', @fh.delete('aB')
    assert_equal 2, @fh.length
    assert_nil @fh.delete('Ab')
    assert_equal 2, @fh.length
  end

  def test_delete_if_and_reject
    assert_equal 3, @fh.length
    hash = @fh.reject{|key, value| key == 'ab' || key == 'cd'}
    assert_equal 1, hash.length
    assert_equal Hash['3'=>'4'], hash
    assert_equal 3, @fh.length
    hash = @fh.delete_if{|key, value| key == 'ab' || key == 'cd'}
    assert_equal 1, hash.length
    assert_equal Hash['3'=>'4'], hash
    assert_equal 1, @fh.length
    assert_equal Hash['3'=>'4'], @fh
    assert_nil  @fh.reject!{|key, value| key == 'ab' || key == 'cd'}
    hash = @fh.reject!{|key, value| key == '3'}
    assert_equal 0, hash.length
    assert_equal Hash[], hash
    assert_equal 0, @fh.length
    assert_equal Hash[], @fh
  end

  def test_dup_and_clone
    def @h.foo; 1; end
    h2 = @h.dup
    h3 = @h.clone
    h2['A'] = '2'
    h3['B'] = '3'
    assert_equal Rack::Headers[], @h
    assert_raises NoMethodError do h2.foo end
    assert_equal 1, h3.foo
    assert_equal '2', h2['a']
    assert_equal '3', h3['b']
  end

  def test_each
    i = 0
    @h.each{i+=1}
    assert_equal 0, i
    items = [['ab','1'], ['cd','2'], ['3','4']]
    @fh.each do |k,v|
      assert items.include?([k,v])
      items -= [[k,v]]
    end
    assert_equal [], items
  end

  def test_each_key
    i = 0
    @h.each{i+=1}
    assert_equal 0, i
    keys = ['ab', 'cd', '3']
    @fh.each_key do |k|
      assert keys.include?(k)
      assert k.frozen?
      keys -= [k]
    end
    assert_equal [], keys
  end

  def test_each_value
    i = 0
    @h.each{i+=1}
    assert_equal 0, i
    values = ['1', '2', '4']
    @fh.each_value do |v|
      assert values.include?(v)
      values -= [v]
    end
    assert_equal [], values
  end

  def test_empty
    assert @h.empty?
    assert !@fh.empty?
  end

  def test_fetch
    assert_raises(ArgumentError){@h.fetch(1,2,3)}
    assert_raises(ArgumentError){@h.fetch(1,2,3){4}}
    assert_raises(IndexError){@h.fetch(1)}
    @h.default = '33'
    assert_raises(IndexError){@h.fetch(1)}
    @h['1'] = '8'
    assert_equal '8', @h.fetch('1')
    assert_equal '3', @h.fetch(2, '3')
    assert_equal '222', @h.fetch('2'){|k| k*3}
    assert_equal '1', @fh.fetch('Ab')
    assert_equal '2', @fh.fetch('cD', '3')
    assert_equal '4', @fh.fetch("3", 3)
    assert_equal '4', @fh.fetch("3"){|k| k*3}
    assert_raises(IndexError){Rack::Headers.new{34}.fetch(1)}
  end

  def test_has_key
    %i'include? has_key? key? member?'.each do |meth|
      assert !@h.send(meth,1)
      assert @fh.send(meth,'Ab')
      assert @fh.send(meth,'cD')
      assert @fh.send(meth,'3')
      assert @fh.send(meth,'ab')
      assert @fh.send(meth,'CD')
      assert @fh.send(meth,'3')
      assert !@fh.send(meth,1)
    end
  end

  def test_has_value
    %i'value? has_value?'.each do |meth|
      assert !@h.send(meth,'1')
      assert @fh.send(meth,'1')
      assert @fh.send(meth,'2')
      assert @fh.send(meth,'4')
      assert !@fh.send(meth,'3')
    end
  end

  def test_inspect
    %i'inspect to_s'.each do |meth|
      assert_equal({}.inspect, @h.send(meth))
      assert_equal({"ab"=>"1", "cd"=>"2", "3"=>"4"}.inspect, @fh.send(meth))
    end
  end

  def test_invert
    assert_kind_of(Rack::Headers, @h.invert)
    assert_equal({}, @h.invert)
    assert_equal({"1"=>"ab", "2"=>"cd", "4"=>"3"}, @fh.invert)
    assert_equal({'cd'=>'ab'}, Rack::Headers['AB'=>'CD'].invert)
    assert_equal({'cd'=>'xy'}, Rack::Headers['AB'=>'Cd', 'xY'=>'cD'].invert)
  end

  def test_keys
    assert_equal [], @h.keys
    assert_equal %w'ab cd 3', @fh.keys
  end

  def test_length
    %i'length size'.each do |meth|
      assert_equal 0, @h.send(meth)
      assert_equal 3, @fh.send(meth)
    end
  end

  def test_merge_and_update
    assert_equal @h, @h.merge({})
    assert_equal @fh, @fh.merge({})
    assert_equal Rack::Headers['ab'=>'55'], @h.merge({'ab'=>'55'})
    assert_equal Rack::Headers[], @h
    assert_equal Rack::Headers['ab'=>'55'], @h.update({'ab'=>'55'})
    assert_equal Rack::Headers['ab'=>'55'], @h
    assert_equal Rack::Headers['ab'=>'55', 'cd'=>'2', '3'=>'4'], @fh.merge({'ab'=>'55'})
    assert_equal Rack::Headers['ab'=>'1', 'cd'=>'2', '3'=>'4'], @fh
    assert_equal Rack::Headers['ab'=>'55', 'cd'=>'2', '3'=>'4'], @fh.merge!({'ab'=>'55'})
    assert_equal Rack::Headers['ab'=>'55', 'cd'=>'2', '3'=>'4'], @fh
    assert_equal Rack::Headers['ab'=>'abss55', 'cd'=>'2', '3'=>'4'], @fh.merge({'ab'=>'ss'}){|k,ov,nv| [k,nv,ov].join}
    assert_equal Rack::Headers['ab'=>'55', 'cd'=>'2', '3'=>'4'], @fh
    assert_equal Rack::Headers['ab'=>'abss55', 'cd'=>'2', '3'=>'4'], @fh.update({'ab'=>'ss'}){|k,ov,nv| [k,nv,ov].join}
    assert_equal Rack::Headers['ab'=>'abss55', 'cd'=>'2', '3'=>'4'], @fh
    assert_equal Rack::Headers['ab'=>'abssabss55', 'cd'=>'2', '3'=>'4'], @fh.merge!({'ab'=>'ss'}){|k,ov,nv| [k,nv,ov].join}
    assert_equal Rack::Headers['ab'=>'abssabss55', 'cd'=>'2', '3'=>'4'], @fh
  end

  def test_replace
    h = @h.dup
    fh = @fh.dup
    h1 = fh.replace(@h)
    assert_equal @h, h1
    assert_same fh, h1

    h2 = h.replace(@fh)
    assert_equal @fh, h2
    assert_same h, h2

    assert_equal @h, fh.replace({})
    assert_equal @fh, h.replace('AB'=>'1', 'cd'=>'2', '3'=>'4')
  end

  def test_select
    assert_equal({}, @h.select{true})
    assert_equal({}, @h.select{false})
    assert_equal({'3' => '4', "ab" => '1', 'cd' => '2'}, @fh.select{true})
    assert_equal({}, @fh.select{false})
    assert_equal({'cd' => '2'}, @fh.select{|k,v| k.start_with?('c')})
    assert_equal({'3' => '4'}, @fh.select{|k,v| v == '4'})
  end

  def test_shift
    assert_nil @h.shift
    array = @fh.to_a
    i = 3
    while true
      assert i >= 0
      kv = @fh.shift
      if kv.nil?
        assert_equal [], array
        break
      else
        i -= 1
        assert array.include?(kv)
        array -= [kv]
      end
    end
    assert_equal [], array
    assert_equal 0, i
  end

  def test_sort
    assert_equal [], @h.sort
    assert_equal [], @h.sort{|a,b| a.to_s<=>b.to_s}
    assert_equal [['ab', '1'], ['cd', '4'], ['ef', '2']], Rack::Headers['CD','4','AB','1','EF','2'].sort
    assert_equal [['3', '4'], ['ab', '1'], ['cd', '2']], @fh.sort{|(ak,av),(bk,bv)| ak.to_s<=>bk.to_s}
  end

  def test_to_a
    assert_equal [], @h.to_a
    assert_equal [['ab', '1'], ['cd', '2'], ['3', '4']], @fh.to_a
  end

  def test_to_hash
    assert_equal Hash[], @h.to_hash
    assert_equal Hash['3','4','ab','1','cd','2'], @fh.to_hash
  end

  def test_values
    assert_equal [], @h.values
    assert_equal ['f', 'c'], Rack::Headers['aB','f','1','c'].values
  end

  def test_values_at
    assert_equal [], @h.values_at()
    assert_equal [nil], @h.values_at(1)
    assert_equal [nil, nil], @h.values_at(1, 1)
    assert_equal [], @fh.values_at()
    assert_equal ['1'], @fh.values_at('AB')
    assert_equal ['2', '1'], @fh.values_at('CD', 'Ab')
    assert_equal ['2', nil, '1'], @fh.values_at('CD', 32, 'aB')
    assert_equal ['4', '2', nil, '1'], @fh.values_at('3', 'CD', 32, 'ab')
  end

  def test_assoc
    assert_nil  @h.assoc(1)
    assert_equal ['ab', '1'], @fh.assoc('Ab')
    assert_equal ['cd', '2'], @fh.assoc('CD')
    assert_nil  @fh.assoc('4')
    assert_equal ['3', '4'], @fh.assoc('3')
  end

  def test_default_proc=
    @h.default_proc = proc{|h, k| k * 2}
    assert_equal 'aa', @h['A']
    @h['Ab'] = '2'
    assert_equal '2', @h['aB']
  end

  def test_flatten
    assert_equal [], @h.flatten
    assert_equal ['ab', '1', 'cd', '2', '3', '4'], @fh.flatten
    @fh['X'] = '56'
    assert_equal ['ab', '1', 'cd', '2', '3', '4', 'x', '56'], @fh.flatten
    assert_equal ['ab', '1', 'cd', '2', '3', '4', 'x', '56'], @fh.flatten(2)
  end

  def test_keep_if
    assert_equal @h, @h.keep_if{|k, v| true}
    assert_equal @fh, @fh.keep_if{|k, v| true}
    assert_equal @h, @fh.dup.keep_if{|k, v| false}
    assert_equal Rack::Headers["AB"=>'1'], @fh.keep_if{|k, v| k == "ab"}
  end

  def test_key
    assert_nil @h.key('1')
    assert_nil @fh.key(1)
    assert_equal 'ab', @fh.key('1')
    assert_equal 'cd', @fh.key('2')
    assert_nil @fh.key('3')
    assert_equal '3', @fh.key('4')
  end

  def test_rassoc
    assert_nil @h.rassoc('1')
    assert_equal ['ab', '1'], @fh.rassoc('1')
    assert_equal ['cd', '2'], @fh.rassoc('2')
    assert_nil @fh.rassoc('3')
    assert_equal ['3', '4'], @fh.rassoc('4')
  end

  def test_select!
    assert_nil @h.select!{|k, v| true}
    assert_nil @fh.select!{|k, v| true}
    assert_equal @h, @fh.dup.select!{|k, v| false}
    assert_equal Rack::Headers["AB"=>'1'], @fh.select!{|k, v| k == "ab"}
  end

  def test_compare_by_identity
    assert_raises(TypeError){@fh.compare_by_identity}
  end

  def test_compare_by_identity?
    assert_equal(false, @fh.compare_by_identity?)
  end

  def test_to_h
    assert_equal Hash[], @h.to_h
    assert_equal Hash['3','4','ab','1','cd','2'], @fh.to_h
  end

  def test_dig
    assert_equal('1', @fh.dig('AB'))
    assert_equal('2', @fh.dig('Cd'))
    assert_equal('4', @fh.dig('3'))
    assert_nil(@fh.dig('4'))

    assert_raises(TypeError){@fh.dig('AB', 1)}
    assert_raises(TypeError){@fh.dig('cd', 2)}
    assert_raises(TypeError){@fh.dig('3', 3)}
    assert_nil(@fh.dig('4', 5))
  end

  def test_fetch_values
    assert_equal(['1'], @fh.fetch_values('AB'))
    assert_equal(['1', '2', '4'], @fh.fetch_values('AB', 'Cd', '3'))
    assert_raises(KeyError){@fh.fetch_values('AB', 'cD', '4')}
  end

  def test_to_proc
    pr = @fh.to_proc
    assert_equal('1', pr['AB'])
    assert_equal('2', pr['cD'])
    assert_equal('4', pr['3'])
    assert_nil(pr['4'])
  end

  def test_compact
    assert_equal(false, @fh.compact.equal?(@fh))
    assert_equal(@fh, @fh.compact)
    assert_equal(Rack::Headers['Ab'=>1], Rack::Headers['aB'=>1, 'cd'=>nil].compact)
  end

  def test_compact!
    fh = @fh.dup
    assert_nil(@fh.compact!)
    assert_equal(fh, @fh)

    h = Rack::Headers['Ab'=>1, 'cd'=>nil]
    assert_equal(Rack::Headers['aB'=>1], h.compact!)
    assert_equal(Rack::Headers['AB'=>1], h)
  end

  def test_transform_values
    fh = @fh.transform_values{|v| v.to_s*2}
    assert_equal('1', @fh['aB'])
    assert_equal(Rack::Headers['AB'=>'11', 'cD'=>'22', '3'=>'44'], fh)
    assert_equal('11', fh['Ab'])
  end

  def test_transform_values!
    @fh.transform_values!{|v| v.to_s*2}
    assert_equal('11', @fh['AB'])
    assert_equal(Rack::Headers['Ab'=>'11', 'CD'=>'22', '3'=>'44'], @fh)
    assert_equal('11', @fh['aB'])
  end

  if RUBY_VERSION >= '2.5'
    def test_slice
      assert_equal(Rack::Headers['Ab'=>'1', 'cD'=>'2', '3'=>'4'], @fh.slice('aB', 'Cd', '3'))
      assert_equal(Rack::Headers['AB'=>'1', 'CD'=>'2'], @fh.slice('Ab', 'CD'))
      assert_equal(Rack::Headers[], @fh.slice('ad'))
      assert_equal('1', @fh.slice('AB', 'cd')['Ab'])
    end

    def test_transform_keys
      map = {'ab'=>'Xy', 'cd'=>'dC', '3'=>'5'}
      dh = @fh.dup
      fh = @fh.transform_keys{|k| map[k]}
      assert_equal(dh, @fh)
      assert_equal('1', fh['xY'])
      assert_equal('2', fh['Dc'])
      assert_equal('4', fh['5'])
    end

    def test_transform_keys!
      map = {'ab'=>'Xy', 'cd'=>'dC', '3'=>'5'}
      dh = @fh.dup
      @fh.transform_keys!{|k| map[k]}
      assert_equal(false, dh == @fh)
      assert_equal('1', @fh['xY'])
      assert_equal('2', @fh['DC'])
      assert_equal('4', @fh['5'])
    end
  end

  if RUBY_VERSION >= '2.6'
    def test_filter!
      assert_nil @h.filter!{|k, v| true}
      assert_nil @fh.filter!{|k, v| true}
      assert_equal @h, @fh.dup.filter!{|k, v| false}
      assert_equal Rack::Headers["AB"=>'1'], @fh.filter!{|k, v| k == "ab"}
    end
  end

  if RUBY_VERSION >= '2.7'
    def test_deconstruct_keys
      assert_equal(@fh.to_hash, @fh.deconstruct_keys([]))
      assert_equal(Rack::Headers, @fh.deconstruct_keys([]).class)
    end
  end

  if RUBY_VERSION >= '3.0'
    def test_except
      @fh = Rack::Headers['AB'=>'1', 'Cd'=>'2', '3'=>'4']
      assert_equal(@fh, @fh.except)
      assert_equal(Rack::Headers['cD'=>'2', '3'=>'4'], @fh.except('AB', 5))
      assert_equal(Rack::Headers['AB'=>'1'], @fh.except('cD', '3'))
    end
  end
end
