#ifndef HASH_MISC_H_
#define HASH_MISC_H_

#include "hash_com.h"

template <class ValueType, class KeyType>
struct __lih_ValKeyPairInt
{
	ValueType val;
	KeyType key;
	bool isempty, isdel;
};

template <class ValueType, class KeyType = bit32_t>
class hash_map_misc:public __lih_hash_base_class<__lih_ValKeyPairInt<ValueType, KeyType> >
{
	typedef __lih_ValKeyPairInt<ValueType, KeyType> ValKeyStruct;
	
	inline bool insert_aux(ValKeyStruct *vkp, size_t m, KeyType key, ValKeyStruct *&p)
	{
		p = __lih_hash_insert_aux(vkp, m, key);
		if (p->isempty) {
			p->key = key;
			p->isempty = false;
		} else if (p->isdel) {
			p->key = key;
			p->isdel = false;
		} else return true;
		return false;
	}
public:
	typedef ValueType value_type;
	typedef KeyType key_type;

	hash_map_misc(void) {};
	~hash_map_misc(void) {};
	inline void resize(size_t m)
	{
		size_t new_m, new_upper;
		new_m = __lih_hash_cal_size(m);
		new_upper = int(new_m * __lih_HASH_UPPER + 0.5);
		// if this->count_n is beyond the new upper boundary, return
		if (this->count_n >= new_upper) return;

		ValKeyStruct *new_vkp, *p, *q;
		new_vkp = (ValKeyStruct*)malloc(new_m * sizeof(ValKeyStruct));
		__lih_hash_clear_aux(new_vkp, new_m);
		
		for (p = this->val_key_pair; p < this->val_key_pair + this->curr_m; p++) {
			if (!p->isempty && !p->isdel) {
				insert_aux(new_vkp, new_m, p->key, q);
				q->val = p->val;
			}
		}
		::free(this->val_key_pair);
		this->val_key_pair = new_vkp;
		this->curr_m = new_m;
		this->upper_bound = new_upper;
	}
	inline bool insert(KeyType key, const ValueType &val)
	{
		ValKeyStruct *p;
		if (this->count_n >= this->upper_bound)
			resize(this->curr_m + 1);
		if (insert_aux(this->val_key_pair, this->curr_m, key, p)) {
			p->val = val;
			return true;
		} else {
			++(this->count_n);
			p->val = val;
			return false;
		}
	}
	inline bool fetch_insert(KeyType key, ValueType **r)
	{
		ValKeyStruct *p;
		if (this->count_n >= this->upper_bound)
			resize(this->curr_m + 1);
		if (insert_aux(this->val_key_pair, this->curr_m, key, p)) {
			*r = &(p->val);
			return true;
		} else {
			++(this->count_n);
			*r = &(p->val);
			return false;
		}
	}
	inline bool find(KeyType key, ValueType *value)
	{
		ValKeyStruct *p;
		p = __lih_hash_search_aux(this->val_key_pair, this->curr_m, key);
		if (p && !p->isempty && !p->isdel) {
			*value = p->val;
			return true;
		}
		return false;
	}
	inline bool erase(KeyType key)
	{
		if (__lih_hash_erase_aux(this->val_key_pair, this->curr_m, key)) {
			--(this->count_n);
			return true;
		}
		return false;
	}
	inline ValueType &locate(KeyType key)
	{
		ValKeyStruct *p;
		if (this->count_n >= this->upper_bound) resize(this->curr_m + 1);
		p = __lih_hash_insert_aux(this->val_key_pair, this->curr_m, key);
		if (p->isempty) {
			p->key = key;
			p->isempty = false;
		} else if (p->isdel) {
			p->key = key;
			p->isdel = false;
		}
		return p->val;
	}
};

template <class KeyType>
struct __lih_KeyStructInt
{
	KeyType key;
	bool isempty, isdel;
};

template <class KeyType>
class hash_set_misc : public __lih_hash_base_class<__lih_KeyStructInt<KeyType> >
{
	typedef __lih_KeyStructInt<KeyType> KeyStruct;
	
	inline bool insert_aux(KeyStruct *vkp, size_t m, KeyType key)
	{
		KeyStruct *p;
		p = __lih_hash_insert_aux(vkp, m, key);
		if (p->isempty) {
			p->key = key;
			p->isempty = false;
		} else if (p->isdel) {
			p->key = key;
			p->isdel = false;
		} else return true;
		return false;
	}
public:
	typedef KeyType key_type;

	hash_set_misc(void) {};
	~hash_set_misc(void) {};
	inline void resize(size_t m)
	{
		size_t new_m, new_upper;
		new_m = __lih_hash_cal_size(m);
		new_upper = int(new_m * __lih_HASH_UPPER + 0.5);
		// if this->count_n is beyond the new upper boundary, return
		if (this->count_n >= new_upper) return;

		KeyStruct *new_vkp, *p;
		new_vkp = (KeyStruct*)malloc(new_m * sizeof(KeyStruct));
		__lih_hash_clear_aux(new_vkp, new_m);
		
		for (p = this->val_key_pair; p < this->val_key_pair + this->curr_m; p++) {
			if (!p->isempty && !p->isdel)
				insert_aux(new_vkp, new_m, p->key);
		}
		::free(this->val_key_pair);
		this->val_key_pair = new_vkp;
		this->curr_m = new_m;
		this->upper_bound = new_upper;
	}
	inline bool insert(KeyType key)
	{
		if (this->count_n >= this->upper_bound)
			resize(this->curr_m + 1);
		if (insert_aux(this->val_key_pair, this->curr_m, key)) return true;
		++(this->count_n);
		return false;
	}
	inline bool find(KeyType key)
	{
		KeyStruct *p;
		p = __lih_hash_search_aux(this->val_key_pair, this->curr_m, key);
		if (p && !p->isempty && !p->isdel) return true;
		return false;
	}
	inline bool erase(KeyType key)
	{
		if (__lih_hash_erase_aux(this->val_key_pair, this->curr_m, key)) {
			--(this->count_n);
			return true;
		}
		return false;
	}
};
#endif // HASH_INT_H_
