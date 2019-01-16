_class={}

function class(super)
    local class_type={}
    class_type.ctor=false
    class_type.super=super
    class_type.new=function(...)
            local obj={}
            do
                local create
                create = function(c,...)
                    if c.super then
                        create(c.super,...)
                    end
                    if c.ctor then
                        c.ctor(obj,...)
                    end
                end

                create(class_type,...)
            end
            setmetatable(obj,{ __index=_class[class_type] })
            return obj
        end
    local vtbl={}
    _class[class_type]=vtbl

    setmetatable(class_type,{__newindex=
        function(t,k,v)
            vtbl[k]=v
        end
    })

    if super then
        setmetatable(vtbl,{__index=
            function(t,k)
                local ret=_class[super][k]
                vtbl[k]=ret
                return ret
            end
        })
    end

    return class_type
end

function recursive_compare(t1,t2)
  -- Use usual comparison first.
  local is_t1_table = (type(t1) == "table")
  local is_t2_table = (type(t2) == "table")
  if (not is_t1_table and not is_t2_table) then
      return (t1==t2)
  end
  -- We only support non-default behavior for tables
  if (not is_t1_table or not is_t2_table) then return false end
  -- They better have the same metatables
  local mt1 = getmetatable(t1)
  local mt2 = getmetatable(t2)
  if( not recursive_compare(mt1,mt2) ) then return false end

  -- Check each key-value pair
  -- We have to do this both ways in case we miss some.
  local checked_key_table = {}
  for k1,v1 in pairs(t1) do
    if not checked_key_table[k1] then
      local v2 = t2[k1]
      if( not recursive_compare(v1,v2) ) then return false end
      checked_key_table[k1] = true
    end
  end
  for k2,v2 in pairs(t2) do
    if not checked_key_table[k2] then
      local v1 = t1[k2]
      if( not recursive_compare(v1,v2) ) then return false end
      checked_key_table[k2] = true
    end
  end

  return true
end
