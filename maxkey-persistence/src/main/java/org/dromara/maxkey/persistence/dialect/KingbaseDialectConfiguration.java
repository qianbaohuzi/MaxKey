/*
 * Copyright [2024] [MaxKey of copyright http://www.maxkey.top]
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 

package org.dromara.maxkey.persistence.dialect;

import org.dromara.mybatis.jpa.dialect.DialectMapper;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 注册 KingbaseES 分页方言。
 * <p>
 * mybatis-jpa-extra 的 {@link DialectMapper} 内置方言表中没有 kingbase，
 * 未注册时会静默回退到 MySQL 方言（LIMIT offset,count），导致 Kingbase 上分页 SQL 报错。
 * 这里在 Bean 实例化之前（BeanFactoryPostProcessor 阶段）补注册。
 * </p>
 */
@Configuration
public class KingbaseDialectConfiguration {

    @Bean
    public static BeanFactoryPostProcessor kingbaseDialectRegistrar() {
        return beanFactory -> DialectMapper.getDialectMap()
                .put(KingbaseDialect.NAME, KingbaseDialect.class.getName());
    }

}
